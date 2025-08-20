// Global theme toggle for all pages
(function(){
    function applyTheme(theme){
        var root = document.documentElement;
        if(theme === 'light'){
            root.setAttribute('data-theme','light');
        } else {
            root.removeAttribute('data-theme'); // default dark
        }
    }
    function currentTheme(){
        return localStorage.getItem('pb_theme') || 'dark';
    }
    function setTheme(theme){
        localStorage.setItem('pb_theme', theme);
        applyTheme(theme);
        updateIcon(theme);
    }
    function updateIcon(theme){
        var btn = document.getElementById('pb-theme-toggle');
        if(!btn) return;
        var icon = btn.querySelector('i');
        if(!icon){ icon = document.createElement('i'); btn.appendChild(icon); }
        icon.className = theme === 'light' ? 'fas fa-moon' : 'fas fa-sun';
        btn.setAttribute('aria-label', theme === 'light' ? 'Switch to dark theme' : 'Switch to light theme');
        btn.title = btn.getAttribute('aria-label');
    }

    function injectToggle(){
        if(document.getElementById('pb-theme-toggle')) return;
        var btn = document.createElement('button');
        btn.id = 'pb-theme-toggle';
        btn.type = 'button';
        btn.className = 'theme-toggle-fab btn btn-sm btn-outline-light';
        btn.innerHTML = '<i class="fas fa-sun"></i>';
        btn.addEventListener('click', function(){
            var next = currentTheme() === 'light' ? 'dark' : 'light';
            setTheme(next);
        });
        document.body.appendChild(btn);
        updateIcon(currentTheme());
    }

    // Expose for reuse if needed
    window.PBTheme = { applyTheme, currentTheme, setTheme, updateIcon };

    // Initialize on DOM ready
    if(document.readyState === 'loading'){
        document.addEventListener('DOMContentLoaded', function(){
            applyTheme(currentTheme());
            injectToggle();
        });
    } else {
        applyTheme(currentTheme());
        injectToggle();
    }
})();

