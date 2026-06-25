function showToast(message, type = 'info') {
    Toastify({
        text: message,
        duration: 3000,
        close: true,
        gravity: "bottom", 
        position: "right", 
        stopOnFocus: true, 
        style: {
            background: type === 'info' ? "#B9823F" : (type === 'success' ? "#4caf50" : "#f44336"),
            borderRadius: "8px",
            boxShadow: "0 4px 12px rgba(0,0,0,0.1)",
            fontFamily: "Inter, sans-serif"
        }
    }).showToast();
}

document.addEventListener("DOMContentLoaded", () => {
    // Add toast to all interactive buttons that don't have href or specific onclick
    const buttons = document.querySelectorAll('button');
    buttons.forEach(btn => {
        if (!btn.hasAttribute('onclick')) {
            btn.addEventListener('click', (e) => {
                e.preventDefault();
                showToast("Mở popup / Xử lý tính năng (Frontend Prototype)");
            });
        }
    });

    // Handle logout click if exists
    const profileSection = document.querySelector('aside .mt-auto');
    if (profileSection) {
        profileSection.addEventListener('click', () => {
            showToast("Mở menu cá nhân (Logout, Settings...)");
        });
    }

    // Set Sidebar active state dynamically
    const currentPath = window.location.pathname;
    const navLinks = document.querySelectorAll('aside nav a');
    navLinks.forEach(link => {
        const href = link.getAttribute('href');
        // Reset all links to inactive state
        link.className = "flex items-center text-[#7A6F63] py-3 px-6 hover:bg-[#B9823F]/5 transition-colors duration-200 group rounded-r-xl";
        const indicator = link.querySelector('.sidebar-active-indicator');
        if(indicator) indicator.remove();

        if (currentPath.includes(href) && href !== '#') {
            link.className = "relative flex items-center bg-[#F3E3CF] text-[#9F6D33] font-semibold py-3 px-6 rounded-r-xl group transition-all duration-200";
            link.innerHTML = '<div class="sidebar-active-indicator" style="position:absolute;left:0;top:0;bottom:0;width:4px;background-color:#B9823F;"></div>' + link.innerHTML;
        } else if (href === '/dashboard' && (currentPath === '/' || currentPath === '/index.html' || currentPath === '')) {
            // fallback dashboard active on root
            link.className = "relative flex items-center bg-[#F3E3CF] text-[#9F6D33] font-semibold py-3 px-6 rounded-r-xl group transition-all duration-200";
            link.innerHTML = '<div class="sidebar-active-indicator" style="position:absolute;left:0;top:0;bottom:0;width:4px;background-color:#B9823F;"></div>' + link.innerHTML;
        }
    });

    // Mock Kanban drag and drop clicks
    const kanbanCards = document.querySelectorAll('.frosted-cream.cursor-move');
    kanbanCards.forEach(card => {
        card.addEventListener('mousedown', () => {
            showToast("Kéo thả cơ hội bán hàng...");
        });
    });
});
