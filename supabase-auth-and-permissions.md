# CRM Đỉnh Phong — Supabase Auth & Phân Quyền

---

## 1. Flow xác thực

### 1.1 Đăng ký bằng email + mật khẩu

```
Client gọi: supabase.auth.signUp({ email, password })
    │
    ▼
Supabase Auth tạo row trong auth.users
    │
    ▼
Trigger on_auth_user_created chạy
    │
    ▼
UPSERT vào public.profiles (id, email, full_name, role='sales')
    │
    ▼
Supabase gửi email xác nhận tới địa chỉ email đã đăng ký
    │
    ▼
User bấm link trong email → email_confirmed_at được set
    │
    ▼
User có thể đăng nhập
```

**Lưu ý quan trọng:**
- Supabase tự chặn đăng nhập cho đến khi email được xác nhận (mặc định bật trong Supabase Dashboard → Authentication → Settings → Enable email confirmations).
- Nếu email đã tồn tại trong auth.users (đã đăng ký qua Google OAuth trước đó), Supabase sẽ trả lỗi `User already registered` — xử lý ở phía client bằng cách gợi ý dùng "Đăng nhập bằng Google".

---

### 1.2 Xác nhận email

```
Supabase gửi email chứa link dạng:
  https://<project>.supabase.co/auth/v1/verify?token=<OTP>&type=signup

User bấm link → Supabase xác nhận → redirect về app với session token
    │
    ▼
Client nhận session qua onAuthStateChange (SIGNED_IN event)
    │
    ▼
Client đọc public.profiles để lấy role và thông tin hiển thị
```

---

### 1.3 Đăng nhập bằng email + mật khẩu

```
Client gọi: supabase.auth.signInWithPassword({ email, password })
    │
    ▼
Supabase kiểm tra email + password trong auth.users
Kiểm tra email_confirmed_at != NULL
    │
    ▼ (thành công)
Trả về session { access_token, refresh_token, user }
    │
    ▼
Client lưu session (Supabase JS SDK tự quản lý qua localStorage)
    │
    ▼
Client gọi: SELECT * FROM public.profiles WHERE id = auth.uid()
Lấy role → điều hướng đến dashboard phù hợp
```

---

### 1.4 Đăng nhập bằng Google OAuth

```
Client gọi: supabase.auth.signInWithOAuth({ provider: 'google' })
    │
    ▼
Redirect sang Google consent screen
    │
    ▼ (user đồng ý)
Google trả về authorization code → Supabase exchange lấy access token
    │
    ▼
Supabase kiểm tra email từ Google trong auth.users:

    Nếu email CHƯA tồn tại:
      → Tạo auth.users row mới
      → Trigger on_auth_user_created chạy
      → UPSERT vào public.profiles (full_name & avatar lấy từ Google metadata)
      → Return session

    Nếu email ĐÃ tồn tại (đã có tài khoản email/password):
      → Supabase tự LINK identity Google vào user hiện có (cùng user_id)
      → Trigger on_auth_user_updated chạy (cập nhật avatar_url nếu chưa có)
      → Return session với cùng user_id cũ
      → Profile KHÔNG bị tạo trùng (UPSERT ON CONFLICT DO NOTHING trên updated_at)
```

**Key point:** Supabase hỗ trợ **automatic identity linking** theo email nếu bật `link_same_email_identities = true` trong Supabase Dashboard (Auth → Settings → User → "Automatically link same-email providers").

---

### 1.5 Quên mật khẩu / Đặt lại mật khẩu

```
Client gọi: supabase.auth.resetPasswordForEmail(email, { redirectTo: 'https://app.dinhphong.vn/reset-password' })
    │
    ▼
Supabase gửi email chứa link đặt lại mật khẩu (valid 1 giờ)
    │
    ▼
User bấm link → app nhận token qua URL fragment/query param
    │
    ▼
Client gọi: supabase.auth.updateUser({ password: newPassword })
    (chỉ hoạt động trong session từ magic link reset)
    │
    ▼
Mật khẩu được cập nhật
    │
    ▼
Redirect về trang đăng nhập
```

---

### 1.6 Logic chống tạo trùng tài khoản

#### Trường hợp 1: Đã có Google OAuth → Thêm email/password

1. User đã đăng nhập bằng Google với `abc@gmail.com`.
2. User cố đăng ký mới bằng email `abc@gmail.com` + mật khẩu.
3. Supabase trả lỗi `User already registered`.
4. **Xử lý phía client:** Hiển thị thông báo "Email này đã được đăng ký. Vui lòng đăng nhập bằng Google hoặc đặt lại mật khẩu."
5. Nếu user muốn thêm mật khẩu vào tài khoản Google, dùng `supabase.auth.updateUser({ password })` khi đã đăng nhập.

#### Trường hợp 2: Đã có email/password → Đăng nhập lần đầu bằng Google

1. User đã có tài khoản email/password với `abc@gmail.com`.
2. User bấm "Đăng nhập bằng Google" với cùng Gmail `abc@gmail.com`.
3. Supabase tự động link Google identity vào `auth.users` row hiện có.
4. Trigger `on_auth_user_updated` chạy → UPSERT profile, cập nhật `avatar_url` nếu cần.
5. `public.profiles.id` **không thay đổi** — role và tất cả dữ liệu CRM giữ nguyên.
6. Từ đây user có thể dùng cả 2 phương thức đăng nhập.

#### Trigger UPSERT tránh trùng profile

```sql
INSERT INTO public.profiles (id, email, full_name, avatar_url, role)
VALUES (NEW.id, NEW.email, v_full_name, v_avatar, 'sales')
ON CONFLICT (id) DO UPDATE SET
  email      = EXCLUDED.email,
  full_name  = COALESCE(EXCLUDED.full_name, profiles.full_name),
  avatar_url = COALESCE(EXCLUDED.avatar_url, profiles.avatar_url),
  updated_at = NOW();
```

- `ON CONFLICT (id)` đảm bảo không bao giờ có 2 profile với cùng `user_id`.
- `COALESCE` đảm bảo không ghi đè data hiện có bằng NULL.

---

## 2. Cơ chế phân quyền

### 2.1 Lưu role

Role được lưu trực tiếp trong `public.profiles.role` kiểu `user_role` ENUM (`admin`, `team_leader`, `sales`).

**Không dùng bảng `user_roles` riêng** vì giai đoạn 1 chỉ có 3 role cố định. Khi cần multi-role hoặc permission granular hơn, có thể tách ra sau.

```sql
-- Đọc role của user hiện tại
SELECT role FROM public.profiles WHERE id = auth.uid();

-- Hoặc dùng helper function
SELECT public.get_my_role();
```

**Admin đổi role cho user:**
```sql
UPDATE public.profiles
SET role = 'team_leader'
WHERE id = '<target_user_id>';
-- Chỉ admin mới có RLS policy UPDATE cho các user khác
```

---

### 2.2 Admin — xem toàn bộ

```
Hàm: public.is_admin() → BOOLEAN
Logic: SELECT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')

Áp dụng cho TẤT CẢ bảng:
  - SELECT: không lọc gì, xem toàn bộ
  - INSERT: không hạn chế
  - UPDATE: không hạn chế
  - DELETE: chỉ admin có quyền xóa leads, opportunities, tasks, subscriptions
```

**Ví dụ policy:**
```sql
CREATE POLICY "leads_select_admin"
  ON public.leads FOR SELECT
  USING (public.is_admin());
```

---

### 2.3 Trưởng nhóm — xem dữ liệu thuộc nhóm mình

```
Hàm: public.get_my_team_ids() → UUID[]
Logic: Trả về array các team_id mà user hiện tại có trong team_members

Hàm: public.get_my_team_member_ids() → UUID[]
Logic: Trả về array các user_id trong tất cả nhóm mà user hiện tại thuộc

Điều kiện SELECT leads:
  team_id = ANY(public.get_my_team_ids())
  AND public.is_team_leader()   -- role IN ('admin', 'team_leader')
```

**Lưu ý:** `is_team_leader()` trả về TRUE cho cả `admin` và `team_leader`. Admin luôn pass tất cả check.

**Trưởng nhóm KHÔNG thể:**
- Xem dữ liệu của nhóm khác
- Xóa leads / opportunities (chỉ admin mới xóa được)
- Thay đổi role của user khác

**Trưởng nhóm CÓ THỂ:**
- Xem và update leads, opportunities, tasks của nhóm mình
- Tạo leads, opportunities, tasks cho thành viên trong nhóm (assigned_to = thành viên nhóm)
- Xem subscription của nhóm mình

---

### 2.4 Sales — chỉ xem dữ liệu do mình phụ trách

```
Điều kiện SELECT leads:
  assigned_to = auth.uid()

Điều kiện SELECT opportunities:
  assigned_to = auth.uid()

Điều kiện SELECT tasks:
  assigned_to = auth.uid()

Điều kiện SELECT subscriptions:
  recorded_by = auth.uid()
```

**Sales KHÔNG thể:**
- Xem leads/opportunities/tasks của Sales khác
- Xóa bất kỳ record nào (chỉ admin)
- Truy cập Cài đặt hệ thống

**Sales CÓ THỂ:**
- Tạo lead mới (assigned_to phải là chính mình)
- Cập nhật leads, opportunities, tasks của mình
- Tạo task mới gắn với lead/opportunity của mình
- Ghi nhận thanh toán (recorded_by = mình)

---

### 2.5 Ma trận phân quyền tóm tắt

| Hành động | Sales | Trưởng nhóm | Admin |
|-----------|-------|-------------|-------|
| Xem profile bản thân | ✅ | ✅ | ✅ |
| Xem profile nhóm | ❌ | ✅ (nhóm mình) | ✅ |
| Xem tất cả profiles | ❌ | ❌ | ✅ |
| Đổi role user | ❌ | ❌ | ✅ |
| Xem leads của mình | ✅ | ✅ | ✅ |
| Xem leads nhóm mình | ❌ | ✅ | ✅ |
| Xem tất cả leads | ❌ | ❌ | ✅ |
| Tạo lead | ✅ (assigned_to=mình) | ✅ (assign cho nhóm) | ✅ |
| Xóa lead | ❌ | ❌ | ✅ |
| Xem opportunities mình phụ trách | ✅ | ✅ | ✅ |
| Xem opportunities nhóm | ❌ | ✅ | ✅ |
| Kéo thả Kanban | ✅ (của mình) | ✅ (của nhóm) | ✅ |
| Xem tasks của mình | ✅ | ✅ | ✅ |
| Xem tasks nhóm | ❌ | ✅ | ✅ |
| Ghi nhận thanh toán | ✅ (của mình) | ✅ (nhóm) | ✅ |
| Cài đặt hệ thống | ❌ | ❌ | ✅ |
| Quản lý teams | ❌ | ❌ | ✅ |
| Xuất CSV | Chỉ dữ liệu mình | Dữ liệu nhóm | Toàn bộ |

---

## 3. Cài đặt Supabase Dashboard cần thiết

### Authentication Settings
```
Dashboard → Authentication → Providers:
  ✅ Email (bật "Confirm email")
  ✅ Google OAuth (điền Client ID + Secret từ Google Cloud Console)

Dashboard → Authentication → Settings:
  ✅ "Automatically link same-email providers" = BẬT
     (đây là key setting để tránh tạo trùng tài khoản)

  Redirect URLs:
    https://app.dinhphong.vn/**
    http://localhost:3000/**  (dev)
```

### Google OAuth cấu hình
```
Google Cloud Console → OAuth 2.0 Client IDs:
  Authorized JavaScript origins: https://app.dinhphong.vn
  Authorized redirect URIs: https://<supabase-project>.supabase.co/auth/v1/callback
```

---

## 4. Sơ đồ quan hệ bảng

```
auth.users (Supabase managed)
    │ 1:1 (trigger upsert)
    ▼
public.profiles ──────────────── role: admin | team_leader | sales
    │
    ├── 1:N ──► team_members ◄──── teams (leader_id → profiles.id)
    │               │
    │               └── team_id → teams.id
    │
    ├── 1:N ──► leads (assigned_to, created_by → profiles.id)
    │               │
    │               ├── 1:N ──► lead_tags ──► lead_lists (product_interest)
    │               │
    │               ├── 1:N ──► opportunities (assigned_to → profiles.id)
    │               │               │
    │               │               ├── stage_id → pipeline_stages.id
    │               │               │
    │               │               └── 1:N ──► tasks
    │               │
    │               ├── 1:N ──► tasks (lead_id)
    │               │
    │               └── 1:N ──► subscriptions (lead_id)
    │
    └── source_id ──► lead_lists (lead_source)
```

---

## 5. Ghi chú triển khai

### Thứ tự chạy SQL
1. Extensions
2. ENUM types
3. Tất cả CREATE TABLE
4. Indexes
5. Functions (helper + trigger functions)
6. Triggers
7. RLS ENABLE
8. Policies
9. Seed data

### Service Role vs Authenticated Role
- `service_role` key (backend/server-side): bypass toàn bộ RLS — chỉ dùng cho migrations, seed data, và admin jobs.
- `anon` key (client-side): chỉ truy cập được khi có active session (auth.uid() != NULL).
- Không bao giờ expose `service_role` key ở frontend.

### pg_cron cho overdue tasks
```sql
-- Chạy mỗi giờ để tự động đánh dấu task quá hạn
SELECT cron.schedule(
  'mark-overdue-tasks',
  '0 * * * *',
  'SELECT public.mark_overdue_tasks()'
);
```

### ENV variables cần có (Next.js / React)
```env
NEXT_PUBLIC_SUPABASE_URL=https://<project>.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=<anon_key>
# Service role key chỉ dùng server-side (không NEXT_PUBLIC_)
SUPABASE_SERVICE_ROLE_KEY=<service_role_key>
```
