// Plasma's standard first-login layout API; user customizations remain editable.
var allDesktops = desktops();
for (var i = 0; i < allDesktops.length; ++i) {
    var desktop = allDesktops[i];
    desktop.wallpaperPlugin = 'org.kde.image';
    desktop.currentConfigGroup = ['Wallpaper', 'org.kde.image', 'General'];
    desktop.writeConfig('Image', 'file:///usr/share/wallpapers/DeadRose/contents/images/3840x2160.png');
}
var dock = new Panel();
dock.location = 'bottom';
dock.alignment = 'center';
dock.height = 64;
dock.lengthMode = 'fit';
dock.floating = true;
dock.hiding = 'dodgewindows';
var launcher = dock.addWidget('org.kde.plasma.kickoff');
launcher.currentConfigGroup = ['General'];
launcher.writeConfig('icon', 'dead-rose');
launcher.writeConfig('favoritesPortedToKAstats', true);
launcher.writeConfig('favorites', ['dead-rose.desktop', 'dead-rose-browser.desktop', 'dead-rose-files.desktop', 'dead-rose-terminal.desktop', 'dead-rose-settings.desktop']);
var tasks = dock.addWidget('org.kde.plasma.icontasks');
tasks.currentConfigGroup = ['General'];
var pinned = ['applications:dead-rose.desktop', 'applications:dead-rose-browser.desktop', 'applications:dead-rose-files.desktop', 'applications:dead-rose-terminal.desktop', 'applications:dead-rose-settings.desktop'];
if (applicationExists('install-dead-rose.desktop')) {
    pinned.push('applications:install-dead-rose.desktop');
}
tasks.writeConfig('launchers', pinned);
dock.addWidget('org.kde.plasma.systemtray');
