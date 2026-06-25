-- ============================================================
-- CRM ĐỈNH PHONG — SUPABASE SCHEMA HOÀN CHỈNH
-- Phiên bản: Giai đoạn 1
-- Ngành: Thương mại & bán lẻ thịt bò cao cấp (Yến Sào Vĩnh Hưng)
-- ============================================================

-- ============================================================
-- PHẦN 0: EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";


-- ============================================================
-- PHẦN 1: ENUM TYPES
-- ============================================================

CREATE TYPE user_role AS ENUM ('admin', 'team_leader', 'sales');

CREATE TYPE lead_status AS ENUM (
  'moi',              -- Mới
  'dang_cham_soc',    -- Đang chăm sóc
  'da_mua',           -- Đã mua
  'khong_tiem_nang',  -- Không tiềm năng
  'ngung_cham_soc'    -- Ngừng chăm sóc
);

CREATE TYPE lead_segment AS ENUM (
  'khach_le',  -- Khách lẻ
  'dai_ly',    -- Đại lý
  'vip'        -- VIP
);

CREATE TYPE opportunity_status AS ENUM (
  'khach_moi',          -- Khách mới
  'dang_tu_van',        -- Đang tư vấn
  'da_gui_bao_gia',     -- Đã gửi báo giá
  'cho_phan_hoi',       -- Chờ phản hồi
  'da_chot',            -- Đã chốt
  'da_thanh_toan',      -- Đã thanh toán
  'mat_co_hoi'          -- Mất cơ hội
);

CREATE TYPE task_status AS ENUM (
  'chua_lam',   -- Chưa làm
  'dang_lam',   -- Đang làm
  'hoan_thanh', -- Hoàn thành
  'qua_han',    -- Quá hạn
  'huy'         -- Hủy
);

CREATE TYPE task_priority AS ENUM (
  'thap',       -- Thấp
  'trung_binh', -- Trung bình
  'cao'         -- Cao
);

CREATE TYPE payment_status AS ENUM (
  'chua_thanh_toan',    -- Chưa thanh toán
  'thanh_toan_mot_phan',-- Thanh toán một phần
  'da_thanh_toan',      -- Đã thanh toán
  'hoan_tien'           -- Hoàn tiền
);

CREATE TYPE payment_method AS ENUM (
  'chuyen_khoan',  -- Chuyển khoản
  'tien_mat',      -- Tiền mặt
  'the',           -- Thẻ
  'momo',          -- MoMo
  'vnpay',         -- VNPay
  'khac'           -- Khác
);

CREATE TYPE activity_action AS ENUM (
  'created', 'updated', 'deleted',
  'status_changed', 'assigned', 'commented',
  'payment_recorded', 'file_uploaded'
);


-- ============================================================
-- PHẦN 2: BẢNG profiles
-- Mỗi auth.users row → đúng 1 profile row (upsert, không tạo trùng)
-- ============================================================

CREATE TABLE public.profiles (
  id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email           TEXT NOT NULL,
  full_name       TEXT,
  avatar_url      TEXT,
  phone           TEXT,
  role            user_role NOT NULL DEFAULT 'sales',
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.profiles IS 'Hồ sơ người dùng — 1:1 với auth.users. Dùng upsert để tránh trùng dù đăng nhập qua email/password hay Google OAuth.';


-- ============================================================
-- PHẦN 3: BẢNG teams & team_members
-- ============================================================

CREATE TABLE public.teams (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        TEXT NOT NULL,
  description TEXT,
  leader_id   UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.teams IS 'Nhóm sales. leader_id trỏ đến profiles.id của Trưởng nhóm.';

CREATE TABLE public.team_members (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  team_id    UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  joined_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (team_id, user_id)
);

COMMENT ON TABLE public.team_members IS 'Quan hệ nhiều-nhiều giữa user và team. Một user có thể thuộc nhiều nhóm nếu cần.';


-- ============================================================
-- PHẦN 4: BẢNG pipeline_stages
-- Danh sách giai đoạn (cột Kanban) — Admin có thể cấu hình
-- ============================================================

CREATE TABLE public.pipeline_stages (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name         TEXT NOT NULL,
  status_key   opportunity_status NOT NULL UNIQUE,
  sort_order   SMALLINT NOT NULL DEFAULT 0,
  color        TEXT,        -- hex color cho UI
  is_active    BOOLEAN NOT NULL DEFAULT TRUE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.pipeline_stages IS 'Cấu hình các cột Kanban cơ hội bán hàng. status_key map 1:1 với enum opportunity_status.';


-- ============================================================
-- PHẦN 5: BẢNG lead_lists (danh mục nguồn khách & sản phẩm quan tâm)
-- Dùng chung cho cả nguồn khách (lead_source) và sản phẩm quan tâm (product_interest)
-- ============================================================

CREATE TABLE public.lead_lists (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  list_type   TEXT NOT NULL CHECK (list_type IN ('lead_source', 'product_interest')),
  name        TEXT NOT NULL,
  sort_order  SMALLINT NOT NULL DEFAULT 0,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (list_type, name)
);

COMMENT ON TABLE public.lead_lists IS 'Danh mục cấu hình dùng chung: nguồn khách (lead_source) và sản phẩm quan tâm (product_interest). Admin có thể thêm/sửa/ẩn.';


-- ============================================================
-- PHẦN 6: BẢNG leads (khách hàng tiềm năng)
-- ============================================================

CREATE TABLE public.leads (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code                TEXT UNIQUE,                         -- Mã khách hàng tự sinh
  full_name           TEXT NOT NULL,
  phone               TEXT,
  email               TEXT,
  segment             lead_segment,
  status              lead_status NOT NULL DEFAULT 'moi',
  address             TEXT,
  notes               TEXT,
  source_id           UUID REFERENCES public.lead_lists(id) ON DELETE SET NULL, -- Nguồn khách
  assigned_to         UUID REFERENCES public.profiles(id) ON DELETE SET NULL,   -- Người phụ trách
  team_id             UUID REFERENCES public.teams(id) ON DELETE SET NULL,       -- Nhóm phụ trách
  created_by          UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Kiểm tra không trùng trong 1 record (phone hoặc email phải có ít nhất 1)
  CONSTRAINT leads_contact_required CHECK (phone IS NOT NULL OR email IS NOT NULL)
);

COMMENT ON TABLE public.leads IS 'Danh sách khách hàng. Mỗi lead thuộc 1 người phụ trách và 1 nhóm.';


-- ============================================================
-- PHẦN 7: BẢNG lead_tags (quan hệ nhiều-nhiều: lead ↔ sản phẩm quan tâm)
-- ============================================================

CREATE TABLE public.lead_tags (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  lead_id      UUID NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
  list_item_id UUID NOT NULL REFERENCES public.lead_lists(id) ON DELETE CASCADE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (lead_id, list_item_id)
);

COMMENT ON TABLE public.lead_tags IS 'Sản phẩm quan tâm của từng khách hàng. Nhiều-nhiều với lead_lists (product_interest).';


-- ============================================================
-- PHẦN 8: BẢNG opportunities (cơ hội bán hàng)
-- ============================================================

CREATE TABLE public.opportunities (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title             TEXT NOT NULL,
  lead_id           UUID NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
  stage_id          UUID REFERENCES public.pipeline_stages(id) ON DELETE SET NULL,
  status            opportunity_status NOT NULL DEFAULT 'khach_moi',
  expected_value    NUMERIC(18, 0),      -- Giá trị dự kiến (VND)
  close_probability SMALLINT CHECK (close_probability BETWEEN 0 AND 100),
  expected_close    DATE,
  notes             TEXT,
  lost_reason       TEXT,                -- Lý do mất cơ hội
  assigned_to       UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  team_id           UUID REFERENCES public.teams(id) ON DELETE SET NULL,
  created_by        UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.opportunities IS 'Cơ hội bán hàng — hiển thị dạng Kanban. Mỗi cơ hội gắn với 1 lead và 1 giai đoạn pipeline.';


-- ============================================================
-- PHẦN 9: BẢNG tasks (công việc follow-up)
-- ============================================================

CREATE TABLE public.tasks (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title          TEXT NOT NULL,
  description    TEXT,
  status         task_status NOT NULL DEFAULT 'chua_lam',
  priority       task_priority NOT NULL DEFAULT 'trung_binh',
  due_date       TIMESTAMPTZ,
  completed_at   TIMESTAMPTZ,
  result_notes   TEXT,                 -- Kết quả xử lý
  lead_id        UUID REFERENCES public.leads(id) ON DELETE SET NULL,
  opportunity_id UUID REFERENCES public.opportunities(id) ON DELETE SET NULL,
  assigned_to    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  team_id        UUID REFERENCES public.teams(id) ON DELETE SET NULL,
  created_by     UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.tasks IS 'Công việc follow-up. Có thể gắn với lead và/hoặc cơ hội bán hàng.';


-- ============================================================
-- PHẦN 10: BẢNG subscriptions (thanh toán)
-- ============================================================

CREATE TABLE public.subscriptions (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code              TEXT UNIQUE,               -- Mã thanh toán
  lead_id           UUID NOT NULL REFERENCES public.leads(id) ON DELETE RESTRICT,
  opportunity_id    UUID REFERENCES public.opportunities(id) ON DELETE SET NULL,
  expected_amount   NUMERIC(18, 0) NOT NULL,   -- Số tiền dự kiến
  paid_amount       NUMERIC(18, 0) DEFAULT 0,  -- Số tiền đã thanh toán
  status            payment_status NOT NULL DEFAULT 'chua_thanh_toan',
  method            payment_method,
  paid_at           TIMESTAMPTZ,
  notes             TEXT,
  recorded_by       UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  team_id           UUID REFERENCES public.teams(id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT subscriptions_amount_positive CHECK (expected_amount > 0),
  CONSTRAINT subscriptions_paid_nonneg CHECK (paid_amount >= 0)
);

COMMENT ON TABLE public.subscriptions IS 'Ghi nhận thanh toán cơ bản. Không thay thế kế toán. Gắn với lead và tùy chọn với cơ hội.';


-- ============================================================
-- PHẦN 11: BẢNG activity_logs (nhật ký hoạt động)
-- ============================================================

CREATE TABLE public.activity_logs (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  actor_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  action       activity_action NOT NULL,
  entity_type  TEXT NOT NULL,    -- 'lead', 'opportunity', 'task', 'subscription', 'profile', ...
  entity_id    UUID NOT NULL,
  old_data     JSONB,            -- Snapshot trước khi thay đổi
  new_data     JSONB,            -- Snapshot sau khi thay đổi
  meta         JSONB,            -- Dữ liệu bổ sung tùy hành động
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.activity_logs IS 'Nhật ký mọi thay đổi quan trọng trong hệ thống. Append-only, không update/delete.';


-- ============================================================
-- PHẦN 12: INDEXES
-- ============================================================

-- profiles
CREATE INDEX idx_profiles_role         ON public.profiles(role);
CREATE INDEX idx_profiles_email        ON public.profiles(email);
CREATE INDEX idx_profiles_is_active    ON public.profiles(is_active);

-- teams
CREATE INDEX idx_teams_leader_id       ON public.teams(leader_id);

-- team_members
CREATE INDEX idx_team_members_user_id  ON public.team_members(user_id);
CREATE INDEX idx_team_members_team_id  ON public.team_members(team_id);

-- leads
CREATE INDEX idx_leads_assigned_to     ON public.leads(assigned_to);
CREATE INDEX idx_leads_team_id         ON public.leads(team_id);
CREATE INDEX idx_leads_status          ON public.leads(status);
CREATE INDEX idx_leads_segment         ON public.leads(segment);
CREATE INDEX idx_leads_phone           ON public.leads(phone);
CREATE INDEX idx_leads_email           ON public.leads(email);
CREATE INDEX idx_leads_created_at      ON public.leads(created_at DESC);
CREATE INDEX idx_leads_source_id       ON public.leads(source_id);

-- lead_tags
CREATE INDEX idx_lead_tags_lead_id     ON public.lead_tags(lead_id);
CREATE INDEX idx_lead_tags_item_id     ON public.lead_tags(list_item_id);

-- opportunities
CREATE INDEX idx_opps_lead_id          ON public.opportunities(lead_id);
CREATE INDEX idx_opps_assigned_to      ON public.opportunities(assigned_to);
CREATE INDEX idx_opps_team_id          ON public.opportunities(team_id);
CREATE INDEX idx_opps_status           ON public.opportunities(status);
CREATE INDEX idx_opps_stage_id         ON public.opportunities(stage_id);
CREATE INDEX idx_opps_expected_close   ON public.opportunities(expected_close);
CREATE INDEX idx_opps_created_at       ON public.opportunities(created_at DESC);

-- tasks
CREATE INDEX idx_tasks_assigned_to     ON public.tasks(assigned_to);
CREATE INDEX idx_tasks_lead_id         ON public.tasks(lead_id);
CREATE INDEX idx_tasks_opportunity_id  ON public.tasks(opportunity_id);
CREATE INDEX idx_tasks_status          ON public.tasks(status);
CREATE INDEX idx_tasks_due_date        ON public.tasks(due_date);
CREATE INDEX idx_tasks_team_id         ON public.tasks(team_id);

-- subscriptions
CREATE INDEX idx_subs_lead_id          ON public.subscriptions(lead_id);
CREATE INDEX idx_subs_opportunity_id   ON public.subscriptions(opportunity_id);
CREATE INDEX idx_subs_recorded_by      ON public.subscriptions(recorded_by);
CREATE INDEX idx_subs_status           ON public.subscriptions(status);
CREATE INDEX idx_subs_team_id          ON public.subscriptions(team_id);
CREATE INDEX idx_subs_paid_at          ON public.subscriptions(paid_at DESC);

-- activity_logs
CREATE INDEX idx_logs_actor_id         ON public.activity_logs(actor_id);
CREATE INDEX idx_logs_entity           ON public.activity_logs(entity_type, entity_id);
CREATE INDEX idx_logs_created_at       ON public.activity_logs(created_at DESC);


-- ============================================================
-- PHẦN 13: HELPER FUNCTIONS (dùng trong RLS)
-- ============================================================

-- Lấy role của user đang đăng nhập
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS user_role
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

-- Kiểm tra user có phải admin không
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$;

-- Kiểm tra user có phải team_leader không
CREATE OR REPLACE FUNCTION public.is_team_leader()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role IN ('admin', 'team_leader')
  );
$$;

-- Lấy danh sách team_id mà user hiện tại là leader hoặc thành viên
CREATE OR REPLACE FUNCTION public.get_my_team_ids()
RETURNS UUID[]
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT ARRAY_AGG(DISTINCT team_id)
  FROM public.team_members
  WHERE user_id = auth.uid();
$$;

-- Lấy danh sách user_id trong cùng nhóm với user hiện tại (dùng cho team_leader)
CREATE OR REPLACE FUNCTION public.get_my_team_member_ids()
RETURNS UUID[]
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT ARRAY_AGG(DISTINCT tm2.user_id)
  FROM public.team_members tm1
  JOIN public.team_members tm2 ON tm1.team_id = tm2.team_id
  WHERE tm1.user_id = auth.uid();
$$;


-- ============================================================
-- PHẦN 14: TRIGGER — Tự tạo profile khi user đăng ký / đăng nhập lần đầu
-- Logic: INSERT hoặc UPDATE auth.users → upsert vào public.profiles
-- Dùng UPSERT (ON CONFLICT DO UPDATE) để tránh tạo trùng profile
-- khi cùng email đăng nhập qua nhiều phương thức (email+pw & Google OAuth)
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_full_name TEXT;
  v_avatar    TEXT;
BEGIN
  -- Lấy full_name từ raw_user_meta_data (Google OAuth cung cấp 'full_name' hoặc 'name')
  v_full_name := COALESCE(
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'name',
    split_part(NEW.email, '@', 1)
  );

  v_avatar := NEW.raw_user_meta_data->>'avatar_url';

  INSERT INTO public.profiles (id, email, full_name, avatar_url, role)
  VALUES (NEW.id, NEW.email, v_full_name, v_avatar, 'sales')
  ON CONFLICT (id) DO UPDATE SET
    email      = EXCLUDED.email,
    full_name  = COALESCE(EXCLUDED.full_name, profiles.full_name),
    avatar_url = COALESCE(EXCLUDED.avatar_url, profiles.avatar_url),
    updated_at = NOW();

  RETURN NEW;
END;
$$;

-- Kích hoạt trigger sau khi INSERT mới vào auth.users
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Kích hoạt trigger sau khi UPDATE auth.users (cập nhật email, metadata từ OAuth)
CREATE OR REPLACE TRIGGER on_auth_user_updated
  AFTER UPDATE ON auth.users
  FOR EACH ROW
  WHEN (OLD.email IS DISTINCT FROM NEW.email OR OLD.raw_user_meta_data IS DISTINCT FROM NEW.raw_user_meta_data)
  EXECUTE FUNCTION public.handle_new_user();


-- ============================================================
-- PHẦN 15: TRIGGER — Tự cập nhật updated_at
-- ============================================================

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_teams_updated_at
  BEFORE UPDATE ON public.teams
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_leads_updated_at
  BEFORE UPDATE ON public.leads
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_opportunities_updated_at
  BEFORE UPDATE ON public.opportunities
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_tasks_updated_at
  BEFORE UPDATE ON public.tasks
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_subscriptions_updated_at
  BEFORE UPDATE ON public.subscriptions
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ============================================================
-- PHẦN 16: TRIGGER — Tự sinh mã khách hàng & mã thanh toán
-- ============================================================

CREATE OR REPLACE FUNCTION public.generate_lead_code()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.code IS NULL THEN
    NEW.code := 'KH-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(nextval('lead_code_seq')::TEXT, 4, '0');
  END IF;
  RETURN NEW;
END;
$$;

CREATE SEQUENCE IF NOT EXISTS lead_code_seq START 1;

CREATE TRIGGER trg_leads_code
  BEFORE INSERT ON public.leads
  FOR EACH ROW EXECUTE FUNCTION public.generate_lead_code();

CREATE OR REPLACE FUNCTION public.generate_subscription_code()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.code IS NULL THEN
    NEW.code := 'TT-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(nextval('subscription_code_seq')::TEXT, 4, '0');
  END IF;
  RETURN NEW;
END;
$$;

CREATE SEQUENCE IF NOT EXISTS subscription_code_seq START 1;

CREATE TRIGGER trg_subscriptions_code
  BEFORE INSERT ON public.subscriptions
  FOR EACH ROW EXECUTE FUNCTION public.generate_subscription_code();


-- ============================================================
-- PHẦN 17: TRIGGER — Tự cập nhật task_status = 'qua_han'
-- Chạy qua pg_cron (bên ngoài Supabase) hoặc gọi từ client.
-- Function dưới đây có thể schedule mỗi giờ:
-- SELECT cron.schedule('mark-overdue-tasks', '0 * * * *', 'SELECT public.mark_overdue_tasks()');
-- ============================================================

CREATE OR REPLACE FUNCTION public.mark_overdue_tasks()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.tasks
  SET status = 'qua_han', updated_at = NOW()
  WHERE status IN ('chua_lam', 'dang_lam')
    AND due_date < NOW();
END;
$$;


-- ============================================================
-- PHẦN 18: ROW LEVEL SECURITY (RLS)
-- Nguyên tắc:
--   Admin    → SELECT/INSERT/UPDATE/DELETE toàn bộ
--   Leader   → SELECT/INSERT/UPDATE dữ liệu của nhóm mình
--   Sales    → SELECT/INSERT/UPDATE dữ liệu do mình phụ trách
-- ============================================================

-- Bật RLS cho tất cả các bảng nghiệp vụ
ALTER TABLE public.profiles         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teams             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_members      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pipeline_stages   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lead_lists        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leads             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lead_tags         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.opportunities     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs     ENABLE ROW LEVEL SECURITY;


-- -----------------------------------------------------------
-- 18.1 profiles
-- -----------------------------------------------------------
-- Mỗi user đọc được profile của mình
CREATE POLICY "profiles_select_own"
  ON public.profiles FOR SELECT
  USING (id = auth.uid());

-- Admin đọc được toàn bộ profiles
CREATE POLICY "profiles_select_admin"
  ON public.profiles FOR SELECT
  USING (public.is_admin());

-- Team leader đọc được profiles của thành viên trong nhóm mình
CREATE POLICY "profiles_select_team_leader"
  ON public.profiles FOR SELECT
  USING (
    public.is_team_leader()
    AND id = ANY(public.get_my_team_member_ids())
  );

-- Mỗi user chỉ update profile của chính mình
CREATE POLICY "profiles_update_own"
  ON public.profiles FOR UPDATE
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- Admin update bất kỳ profile
CREATE POLICY "profiles_update_admin"
  ON public.profiles FOR UPDATE
  USING (public.is_admin());

-- INSERT được handle bởi trigger handle_new_user (service role), không cần policy INSERT cho anon/user
-- Nhưng cần cho service_role bypass RLS (Supabase làm tự động).


-- -----------------------------------------------------------
-- 18.2 teams
-- -----------------------------------------------------------
-- Ai cũng đọc được teams mình thuộc về
CREATE POLICY "teams_select_member"
  ON public.teams FOR SELECT
  USING (
    public.is_admin()
    OR id = ANY(public.get_my_team_ids())
  );

-- Admin CRUD toàn bộ teams
CREATE POLICY "teams_all_admin"
  ON public.teams FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());


-- -----------------------------------------------------------
-- 18.3 team_members
-- -----------------------------------------------------------
-- Ai cũng xem được thành viên của nhóm mình
CREATE POLICY "team_members_select"
  ON public.team_members FOR SELECT
  USING (
    public.is_admin()
    OR team_id = ANY(public.get_my_team_ids())
  );

-- Admin CRUD toàn bộ
CREATE POLICY "team_members_all_admin"
  ON public.team_members FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());


-- -----------------------------------------------------------
-- 18.4 pipeline_stages — đọc cho tất cả, write chỉ admin
-- -----------------------------------------------------------
CREATE POLICY "pipeline_stages_select_all"
  ON public.pipeline_stages FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "pipeline_stages_write_admin"
  ON public.pipeline_stages FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());


-- -----------------------------------------------------------
-- 18.5 lead_lists — đọc cho tất cả, write chỉ admin
-- -----------------------------------------------------------
CREATE POLICY "lead_lists_select_all"
  ON public.lead_lists FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "lead_lists_write_admin"
  ON public.lead_lists FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());


-- -----------------------------------------------------------
-- 18.6 leads
-- -----------------------------------------------------------
-- Sales chỉ đọc leads do mình phụ trách
CREATE POLICY "leads_select_own"
  ON public.leads FOR SELECT
  USING (assigned_to = auth.uid());

-- Team leader đọc leads của nhóm mình
CREATE POLICY "leads_select_team_leader"
  ON public.leads FOR SELECT
  USING (
    public.is_team_leader()
    AND team_id = ANY(public.get_my_team_ids())
  );

-- Admin đọc toàn bộ
CREATE POLICY "leads_select_admin"
  ON public.leads FOR SELECT
  USING (public.is_admin());

-- Sales tạo lead mới (assigned_to phải là chính mình)
CREATE POLICY "leads_insert_sales"
  ON public.leads FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND (assigned_to = auth.uid() OR public.is_team_leader() OR public.is_admin())
  );

-- Sales chỉ update leads do mình phụ trách
CREATE POLICY "leads_update_own"
  ON public.leads FOR UPDATE
  USING (assigned_to = auth.uid())
  WITH CHECK (assigned_to = auth.uid());

-- Team leader update leads của nhóm mình
CREATE POLICY "leads_update_team_leader"
  ON public.leads FOR UPDATE
  USING (
    public.is_team_leader()
    AND team_id = ANY(public.get_my_team_ids())
  );

-- Admin update toàn bộ
CREATE POLICY "leads_update_admin"
  ON public.leads FOR UPDATE
  USING (public.is_admin());

-- Admin delete leads
CREATE POLICY "leads_delete_admin"
  ON public.leads FOR DELETE
  USING (public.is_admin());


-- -----------------------------------------------------------
-- 18.7 lead_tags (theo quyền của lead gốc)
-- -----------------------------------------------------------
CREATE POLICY "lead_tags_select"
  ON public.lead_tags FOR SELECT
  USING (
    public.is_admin()
    OR EXISTS (
      SELECT 1 FROM public.leads l
      WHERE l.id = lead_tags.lead_id
        AND (
          l.assigned_to = auth.uid()
          OR (public.is_team_leader() AND l.team_id = ANY(public.get_my_team_ids()))
        )
    )
  );

CREATE POLICY "lead_tags_insert"
  ON public.lead_tags FOR INSERT
  WITH CHECK (
    public.is_admin()
    OR EXISTS (
      SELECT 1 FROM public.leads l
      WHERE l.id = lead_tags.lead_id
        AND (
          l.assigned_to = auth.uid()
          OR (public.is_team_leader() AND l.team_id = ANY(public.get_my_team_ids()))
        )
    )
  );

CREATE POLICY "lead_tags_delete"
  ON public.lead_tags FOR DELETE
  USING (
    public.is_admin()
    OR EXISTS (
      SELECT 1 FROM public.leads l
      WHERE l.id = lead_tags.lead_id
        AND (
          l.assigned_to = auth.uid()
          OR (public.is_team_leader() AND l.team_id = ANY(public.get_my_team_ids()))
        )
    )
  );


-- -----------------------------------------------------------
-- 18.8 opportunities
-- -----------------------------------------------------------
CREATE POLICY "opps_select_own"
  ON public.opportunities FOR SELECT
  USING (assigned_to = auth.uid());

CREATE POLICY "opps_select_team_leader"
  ON public.opportunities FOR SELECT
  USING (
    public.is_team_leader()
    AND team_id = ANY(public.get_my_team_ids())
  );

CREATE POLICY "opps_select_admin"
  ON public.opportunities FOR SELECT
  USING (public.is_admin());

CREATE POLICY "opps_insert"
  ON public.opportunities FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND (assigned_to = auth.uid() OR public.is_team_leader() OR public.is_admin())
  );

CREATE POLICY "opps_update_own"
  ON public.opportunities FOR UPDATE
  USING (assigned_to = auth.uid())
  WITH CHECK (assigned_to = auth.uid());

CREATE POLICY "opps_update_team_leader"
  ON public.opportunities FOR UPDATE
  USING (
    public.is_team_leader()
    AND team_id = ANY(public.get_my_team_ids())
  );

CREATE POLICY "opps_update_admin"
  ON public.opportunities FOR UPDATE
  USING (public.is_admin());

CREATE POLICY "opps_delete_admin"
  ON public.opportunities FOR DELETE
  USING (public.is_admin());


-- -----------------------------------------------------------
-- 18.9 tasks
-- -----------------------------------------------------------
CREATE POLICY "tasks_select_own"
  ON public.tasks FOR SELECT
  USING (assigned_to = auth.uid());

CREATE POLICY "tasks_select_team_leader"
  ON public.tasks FOR SELECT
  USING (
    public.is_team_leader()
    AND team_id = ANY(public.get_my_team_ids())
  );

CREATE POLICY "tasks_select_admin"
  ON public.tasks FOR SELECT
  USING (public.is_admin());

CREATE POLICY "tasks_insert"
  ON public.tasks FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND (assigned_to = auth.uid() OR public.is_team_leader() OR public.is_admin())
  );

CREATE POLICY "tasks_update_own"
  ON public.tasks FOR UPDATE
  USING (assigned_to = auth.uid())
  WITH CHECK (assigned_to = auth.uid());

CREATE POLICY "tasks_update_team_leader"
  ON public.tasks FOR UPDATE
  USING (
    public.is_team_leader()
    AND team_id = ANY(public.get_my_team_ids())
  );

CREATE POLICY "tasks_update_admin"
  ON public.tasks FOR UPDATE
  USING (public.is_admin());

CREATE POLICY "tasks_delete_admin"
  ON public.tasks FOR DELETE
  USING (public.is_admin());


-- -----------------------------------------------------------
-- 18.10 subscriptions
-- -----------------------------------------------------------
CREATE POLICY "subs_select_own"
  ON public.subscriptions FOR SELECT
  USING (recorded_by = auth.uid());

CREATE POLICY "subs_select_team_leader"
  ON public.subscriptions FOR SELECT
  USING (
    public.is_team_leader()
    AND team_id = ANY(public.get_my_team_ids())
  );

CREATE POLICY "subs_select_admin"
  ON public.subscriptions FOR SELECT
  USING (public.is_admin());

CREATE POLICY "subs_insert"
  ON public.subscriptions FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND (recorded_by = auth.uid() OR public.is_admin())
  );

CREATE POLICY "subs_update_own"
  ON public.subscriptions FOR UPDATE
  USING (recorded_by = auth.uid())
  WITH CHECK (recorded_by = auth.uid());

CREATE POLICY "subs_update_team_leader"
  ON public.subscriptions FOR UPDATE
  USING (
    public.is_team_leader()
    AND team_id = ANY(public.get_my_team_ids())
  );

CREATE POLICY "subs_update_admin"
  ON public.subscriptions FOR UPDATE
  USING (public.is_admin());

CREATE POLICY "subs_delete_admin"
  ON public.subscriptions FOR DELETE
  USING (public.is_admin());


-- -----------------------------------------------------------
-- 18.11 activity_logs — đọc theo phạm vi quyền, không ai được delete
-- -----------------------------------------------------------
CREATE POLICY "logs_select_own"
  ON public.activity_logs FOR SELECT
  USING (actor_id = auth.uid());

CREATE POLICY "logs_select_team_leader"
  ON public.activity_logs FOR SELECT
  USING (
    public.is_team_leader()
    AND actor_id = ANY(public.get_my_team_member_ids())
  );

CREATE POLICY "logs_select_admin"
  ON public.activity_logs FOR SELECT
  USING (public.is_admin());

-- Chỉ hệ thống (service role) mới INSERT log, không cần policy riêng cho user role
-- (Supabase service_role bypass RLS)


-- ============================================================
-- PHẦN 19: SEED DATA — Dữ liệu mẫu Yến Sào Vĩnh Hưng
-- ============================================================

-- 19.1 Pipeline stages (cột Kanban)
INSERT INTO public.pipeline_stages (name, status_key, sort_order, color) VALUES
  ('Khách mới',        'khach_moi',        1, '#B9823F'),
  ('Đang tư vấn',      'dang_tu_van',      2, '#9F6D33'),
  ('Đã gửi báo giá',   'da_gui_bao_gia',   3, '#7A6F63'),
  ('Chờ phản hồi',     'cho_phan_hoi',     4, '#6B6259'),
  ('Đã chốt',          'da_chot',          5, '#4F4A43'),
  ('Đã thanh toán',    'da_thanh_toan',    6, '#241F1A'),
  ('Mất cơ hội',       'mat_co_hoi',       7, '#E6DED5');

-- 19.2 Lead lists — nguồn khách
INSERT INTO public.lead_lists (list_type, name, sort_order) VALUES
  ('lead_source', 'Cửa hàng trực tiếp',       1),
  ('lead_source', 'Zalo',                      2),
  ('lead_source', 'Facebook / Fanpage',        3),
  ('lead_source', 'Điện thoại',                4),
  ('lead_source', 'Giới thiệu cá nhân',        5),
  ('lead_source', 'Nhà hàng / Đối tác F&B',   6),
  ('lead_source', 'Sự kiện',                   7),
  ('lead_source', 'Nhân viên Sales trực tiếp', 8),
  ('lead_source', 'Khác',                      9);

-- 19.3 Lead lists — sản phẩm quan tâm
INSERT INTO public.lead_lists (list_type, name, sort_order) VALUES
  ('product_interest', 'Wagyu cao cấp',              1),
  ('product_interest', 'Angus cao cấp',              2),
  ('product_interest', 'Ribeye',                     3),
  ('product_interest', 'Striploin',                  4),
  ('product_interest', 'Tenderloin',                 5),
  ('product_interest', 'Short Rib',                  6),
  ('product_interest', 'Tomahawk',                   7),
  ('product_interest', 'T-bone',                     8),
  ('product_interest', 'Set Steak Night',             9),
  ('product_interest', 'Set Weekend BBQ',            10),
  ('product_interest', 'Set Hotpot & Shabu',         11),
  ('product_interest', 'Thịt thái lát nhúng lẩu',   12),
  ('product_interest', 'Sản phẩm dry-aged',          13),
  ('product_interest', 'Combo gia đình',             14),
  ('product_interest', 'Quà biếu cao cấp',           15),
  ('product_interest', 'Nguồn cung nhà hàng',        16),
  ('product_interest', 'Nguồn cung đại lý',          17);

-- 19.4 Profiles mẫu (UUID cố định cho seed, không liên kết auth.users thật)
-- NOTE: Trên production, profiles được tạo tự động qua trigger handle_new_user.
--       Seed dưới đây CHỈ dùng cho môi trường dev/test.

-- Admin
INSERT INTO public.profiles (id, email, full_name, role) VALUES
  ('00000000-0000-0000-0000-000000000001', 'admin@dinhphong.vn', 'Nguyễn Admin Đỉnh Phong', 'admin');

-- Trưởng nhóm
INSERT INTO public.profiles (id, email, full_name, role) VALUES
  ('00000000-0000-0000-0000-000000000002', 'leader1@dinhphong.vn', 'Trần Thị Lan - Trưởng nhóm A', 'team_leader'),
  ('00000000-0000-0000-0000-000000000003', 'leader2@dinhphong.vn', 'Lê Văn Hùng - Trưởng nhóm B', 'team_leader');

-- Sales
INSERT INTO public.profiles (id, email, full_name, role) VALUES
  ('00000000-0000-0000-0000-000000000004', 'sales1@dinhphong.vn', 'Phạm Minh Tuấn', 'sales'),
  ('00000000-0000-0000-0000-000000000005', 'sales2@dinhphong.vn', 'Nguyễn Thị Mai', 'sales'),
  ('00000000-0000-0000-0000-000000000006', 'sales3@dinhphong.vn', 'Võ Thành Nhân', 'sales'),
  ('00000000-0000-0000-0000-000000000007', 'sales4@dinhphong.vn', 'Đặng Thị Hoa', 'sales');

-- 19.5 Teams
INSERT INTO public.teams (id, name, description, leader_id) VALUES
  ('10000000-0000-0000-0000-000000000001', 'Nhóm A - Hà Nội', 'Nhóm kinh doanh khu vực Hà Nội', '00000000-0000-0000-0000-000000000002'),
  ('10000000-0000-0000-0000-000000000002', 'Nhóm B - TP.HCM', 'Nhóm kinh doanh khu vực TP.HCM', '00000000-0000-0000-0000-000000000003');

-- 19.6 Team members
INSERT INTO public.team_members (team_id, user_id) VALUES
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002'),
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000004'),
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000005'),
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003'),
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000006'),
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000007');

-- 19.7 Leads mẫu
INSERT INTO public.leads (id, full_name, phone, email, segment, status, notes, assigned_to, team_id, created_by, source_id)
SELECT
  '20000000-0000-0000-0000-000000000001',
  'Chị Nguyễn Thanh Hà',
  '0901234567',
  'ha.nguyen@gmail.com',
  'vip',
  'dang_cham_soc',
  'Khách VIP thường mua Wagyu set cuối tuần. Ưu tiên giao hàng trước 10h sáng.',
  '00000000-0000-0000-0000-000000000004',
  '10000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000004',
  (SELECT id FROM public.lead_lists WHERE list_type = 'lead_source' AND name = 'Giới thiệu cá nhân');

INSERT INTO public.leads (id, full_name, phone, email, segment, status, notes, assigned_to, team_id, created_by, source_id)
SELECT
  '20000000-0000-0000-0000-000000000002',
  'Nhà hàng Bò Tươi Sài Gòn',
  '0287654321',
  'contact@bothuoisaigon.com',
  'dai_ly',
  'dang_cham_soc',
  'Nhà hàng quan tâm Ribeye và Short Rib số lượng lớn. Cần báo giá sỉ.',
  '00000000-0000-0000-0000-000000000006',
  '10000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000006',
  (SELECT id FROM public.lead_lists WHERE list_type = 'lead_source' AND name = 'Nhà hàng / Đối tác F&B');

INSERT INTO public.leads (id, full_name, phone, email, segment, status, notes, assigned_to, team_id, created_by, source_id)
SELECT
  '20000000-0000-0000-0000-000000000003',
  'Anh Trần Đức Minh',
  '0912345678',
  NULL,
  'khach_le',
  'moi',
  'Khách hỏi combo gia đình Wagyu qua Facebook. Chưa xác nhận nhu cầu cụ thể.',
  '00000000-0000-0000-0000-000000000005',
  '10000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000005',
  (SELECT id FROM public.lead_lists WHERE list_type = 'lead_source' AND name = 'Facebook / Fanpage');

-- 19.8 Lead tags (sản phẩm quan tâm)
INSERT INTO public.lead_tags (lead_id, list_item_id)
SELECT '20000000-0000-0000-0000-000000000001', id FROM public.lead_lists WHERE name = 'Wagyu cao cấp';

INSERT INTO public.lead_tags (lead_id, list_item_id)
SELECT '20000000-0000-0000-0000-000000000001', id FROM public.lead_lists WHERE name = 'Set Steak Night';

INSERT INTO public.lead_tags (lead_id, list_item_id)
SELECT '20000000-0000-0000-0000-000000000002', id FROM public.lead_lists WHERE name = 'Ribeye';

INSERT INTO public.lead_tags (lead_id, list_item_id)
SELECT '20000000-0000-0000-0000-000000000002', id FROM public.lead_lists WHERE name = 'Short Rib';

INSERT INTO public.lead_tags (lead_id, list_item_id)
SELECT '20000000-0000-0000-0000-000000000002', id FROM public.lead_lists WHERE name = 'Nguồn cung nhà hàng';

INSERT INTO public.lead_tags (lead_id, list_item_id)
SELECT '20000000-0000-0000-0000-000000000003', id FROM public.lead_lists WHERE name = 'Combo gia đình';

-- 19.9 Opportunities mẫu
INSERT INTO public.opportunities (id, title, lead_id, status, expected_value, close_probability, expected_close, notes, assigned_to, team_id, created_by)
VALUES
  (
    '30000000-0000-0000-0000-000000000001',
    'Chị Hà - Set Wagyu cuối tuần tháng 7',
    '20000000-0000-0000-0000-000000000001',
    'cho_phan_hoi',
    4500000,
    70,
    '2026-07-15',
    'Khách muốn set 4 người. Đã gửi báo giá Wagyu A5 500g + Side. Chờ xác nhận.',
    '00000000-0000-0000-0000-000000000004',
    '10000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000004'
  ),
  (
    '30000000-0000-0000-0000-000000000002',
    'Bò Tươi Sài Gòn - Nguồn cung Ribeye tháng 7-8',
    '20000000-0000-0000-0000-000000000002',
    'dang_tu_van',
    85000000,
    50,
    '2026-07-31',
    'Nhà hàng cần ~20kg Ribeye/tuần. Đang tư vấn về giá sỉ và điều khoản giao hàng.',
    '00000000-0000-0000-0000-000000000006',
    '10000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000006'
  ),
  (
    '30000000-0000-0000-0000-000000000003',
    'Anh Minh - Combo gia đình lần đầu',
    '20000000-0000-0000-0000-000000000003',
    'khach_moi',
    1800000,
    30,
    '2026-07-05',
    'Khách mới, chưa xác nhận số lượng. Cần gọi lại để tư vấn combo phù hợp.',
    '00000000-0000-0000-0000-000000000005',
    '10000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000005'
  );

-- Update stage_id từ pipeline_stages
UPDATE public.opportunities SET stage_id = (SELECT id FROM public.pipeline_stages WHERE status_key = status);

-- 19.10 Tasks mẫu
INSERT INTO public.tasks (title, status, priority, due_date, lead_id, opportunity_id, assigned_to, team_id, created_by, description)
VALUES
  (
    'Gọi lại xác nhận đơn Set Wagyu chị Hà',
    'chua_lam',
    'cao',
    '2026-06-25 10:00:00+07',
    '20000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000004',
    '10000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000004',
    'Khách đang chờ xác nhận. Gọi trước 10h để hỏi thêm về khẩu vị và ngày giao.'
  ),
  (
    'Gửi báo giá sỉ Ribeye & Short Rib cho Bò Tươi Sài Gòn',
    'dang_lam',
    'cao',
    '2026-06-24 17:00:00+07',
    '20000000-0000-0000-0000-000000000002',
    '30000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000006',
    '10000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000006',
    'Gửi bảng giá sỉ tuần và chính sách thanh toán cho nhà hàng.'
  ),
  (
    'Gọi tư vấn combo gia đình cho anh Minh',
    'chua_lam',
    'trung_binh',
    '2026-06-26 09:00:00+07',
    '20000000-0000-0000-0000-000000000003',
    '30000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000005',
    '10000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000005',
    'Tư vấn set combo 4-6 người, giới thiệu Combo gia đình Wagyu + Angus.'
  );

-- 19.11 Subscription mẫu
INSERT INTO public.subscriptions (lead_id, opportunity_id, expected_amount, paid_amount, status, method, notes, recorded_by, team_id)
VALUES
  (
    '20000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    4500000,
    0,
    'chua_thanh_toan',
    'chuyen_khoan',
    'Đặt cọc 50% khi xác nhận đơn. Chờ phản hồi từ khách.',
    '00000000-0000-0000-0000-000000000004',
    '10000000-0000-0000-0000-000000000001'
  );
