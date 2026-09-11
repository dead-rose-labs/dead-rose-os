#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo DEAD_ROSE_LIVE_FAILED; journalctl -b -n 160 --no-pager' ERR
[[ $(tr -d '\000' < /sys/firmware/qemu_fw_cfg/by_name/opt/deadrose/ci/raw) == 1 ]]
test -d /sys/firmware/efi
systemctl is-active --quiet graphical.target
systemctl is-active --quiet NetworkManager.service
nm-online --quiet --timeout=60
echo DEAD_ROSE_LIVE_READY
systemctl is-active --quiet sddm.service
echo DEAD_ROSE_SDDM_READY
test -f /usr/share/wayland-sessions/plasma.desktop
deadline=$((SECONDS + 150))
ready=false
while (( SECONDS < deadline )); do
    while read -r session; do
        [[ -n $session ]] || continue
        if [[ $(loginctl show-session "$session" -p Name --value) == live &&
              $(loginctl show-session "$session" -p Type --value) == wayland &&
              $(loginctl show-session "$session" -p Active --value) == yes ]] &&
              pgrep -u live -x plasmashell && pgrep -u live -x kwin_wayland; then
            ready=true
            break
        fi
    done < <(loginctl list-sessions --no-legend | awk '{print $1}')
    [[ $ready == false ]] || break
    # A bounded readiness probe, with no restarts or boot fixes.
    sleep 1
done
[[ $ready == true ]]
test -x /usr/bin/calamares
test -s /etc/calamares/settings.conf
test -s /usr/share/wallpapers/DeadRose/contents/images/3840x2160.png
echo DEAD_ROSE_PLASMA_READY
