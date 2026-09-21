(() => {
    'use strict';

    const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'codera-hud';

    const post = (name, body = {}) => fetch(`https://${RESOURCE}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(body)
    })
        .then((response) => response.text())
        .then((text) => {
            try { return JSON.parse(text); } catch (error) { return text; }
        })
        .catch(() => null);

    const CLOSE_ANIM_MS = 280;
    let closeTimer = null;

    const elements = {
        menu: document.getElementById('vehicle-menu'),
        backdrop: document.getElementById('vehicle-menu-backdrop'),
        closeButton: document.getElementById('vehicle-menu-close'),
        seats: document.getElementById('vm-seats'),
        aux: document.getElementById('vm-aux'),
        doors: document.getElementById('vm-doors'),
        windows: document.getElementById('vm-windows'),
        body: document.getElementById('vm-body'),
        driving: document.getElementById('vm-driving'),
        extras: document.getElementById('vm-extras')
    };

    const DOOR_LABELS = { 0: 'FL DOOR', 1: 'FR DOOR', 2: 'RL DOOR', 3: 'RR DOOR' };
    const WINDOW_LABELS = { 0: 'FL WIN', 1: 'FR WIN', 2: 'RL WIN', 3: 'RR WIN' };

    const makeButton = ({ icon, label, active, warning, disabled, onClick }) => {
        const btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'vm-btn';
        if (active) btn.classList.add('is-active');
        if (warning) btn.classList.add('is-warning');
        if (disabled) btn.classList.add('is-disabled');

        const iconEl = document.createElement('i');
        iconEl.className = `fa-solid ${icon}`;
        btn.appendChild(iconEl);

        const labelEl = document.createElement('span');
        labelEl.className = 'vm-btn__label';
        labelEl.textContent = label;
        btn.appendChild(labelEl);

        if (onClick && !disabled) {
            btn.addEventListener('click', onClick);
        }

        return btn;
    };

    const render = (state) => {
        elements.seats.innerHTML = '';
        (state.seats || []).forEach((seat) => {
            elements.seats.appendChild(makeButton({
                icon: 'fa-chair',
                label: seat.index === -1 ? 'DRIVER' : `SEAT ${seat.index + 1}`,
                active: seat.current,
                disabled: seat.occupied && !seat.current,
                onClick: () => post('vehiclemenu_seat', { seat: seat.index })
            }));
        });

        elements.aux.innerHTML = '';
        elements.aux.appendChild(makeButton({
            icon: 'fa-power-off',
            label: 'ENGINE',
            active: state.engineOn,
            onClick: () => post('vehiclemenu_engine')
        }));
        elements.aux.appendChild(makeButton({
            icon: 'fa-lightbulb',
            label: 'LIGHTS',
            active: state.lightsOn,
            onClick: () => post('vehiclemenu_lights')
        }));
        elements.aux.appendChild(makeButton({
            icon: 'fa-sun',
            label: 'HIGH BEAM',
            active: state.fullbeamOn,
            disabled: !state.lightsOn,
            onClick: () => post('vehiclemenu_highbeam')
        }));
        elements.aux.appendChild(makeButton({
            icon: 'fa-lightbulb',
            label: 'CABIN',
            active: state.interiorLightOn,
            onClick: () => post('vehiclemenu_interior')
        }));
        elements.aux.appendChild(makeButton({
            icon: 'fa-triangle-exclamation',
            label: 'HAZARD',
            warning: true,
            active: state.hazardOn,
            onClick: () => post('vehiclemenu_hazard')
        }));
        elements.aux.appendChild(makeButton({
            icon: 'fa-bell',
            label: 'ALARM',
            warning: true,
            active: state.alarmOn,
            onClick: () => post('vehiclemenu_alarm')
        }));

        elements.doors.innerHTML = '';
        [0, 1, 2, 3].forEach((index) => {
            elements.doors.appendChild(makeButton({
                icon: 'fa-door-open',
                label: DOOR_LABELS[index],
                active: state.doors && state.doors[String(index)],
                onClick: () => post('vehiclemenu_door', { index })
            }));
        });

        elements.windows.innerHTML = '';
        [0, 1, 2, 3].forEach((index) => {
            elements.windows.appendChild(makeButton({
                icon: state.windows && state.windows[String(index)] ? 'fa-window-minimize' : 'fa-window-maximize',
                label: WINDOW_LABELS[index],
                active: state.windows && state.windows[String(index)],
                onClick: () => post('vehiclemenu_window', { index })
            }));
        });

        elements.body.innerHTML = '';
        elements.body.appendChild(makeButton({
            icon: 'fa-car',
            label: 'HOOD',
            active: state.hoodOpen,
            onClick: () => post('vehiclemenu_hood')
        }));
        elements.body.appendChild(makeButton({
            icon: 'fa-box',
            label: 'TRUNK',
            active: state.trunkOpen,
            onClick: () => post('vehiclemenu_trunk')
        }));

        elements.driving.innerHTML = '';
        elements.driving.appendChild(makeButton({
            icon: 'fa-gear',
            label: 'MANUAL',
            active: state.manual,
            onClick: () => post('vehiclemenu_manual')
        }));
        elements.driving.appendChild(makeButton({
            icon: 'fa-gear',
            label: 'LAUNCH',
            active: state.launch,
            onClick: () => post('vehiclemenu_launch')
        }));
        elements.driving.appendChild(makeButton({
            icon: 'fa-triangle-exclamation',
            label: 'TCS',
            warning: true,
            active: !state.tcs,
            onClick: () => post('vehiclemenu_tcs')
        }));
        elements.driving.appendChild(makeButton({
            icon: 'fa-triangle-exclamation',
            label: 'ESC',
            warning: true,
            active: !state.esc,
            onClick: () => post('vehiclemenu_esc')
        }));

        elements.extras.innerHTML = '';
        Object.keys(state.extras || {})
            .sort((a, b) => Number(a) - Number(b))
            .forEach((id) => {
                elements.extras.appendChild(makeButton({
                    icon: 'fa-star',
                    label: `EXTRA ${id}`,
                    active: state.extras[id],
                    onClick: () => post('vehiclemenu_extra', { id: Number(id) })
                }));
            });
    };

    const openMenu = (state) => {
        window.clearTimeout(closeTimer);
        elements.menu.hidden = false;
        elements.backdrop.hidden = false;
        document.body.classList.add('vehicle-menu-open');
        render(state);

        // Two rAFs so the browser commits the "closed" (offset/invisible)
        // state from the previous paint before switching to .is-open -
        // otherwise the transition gets skipped and it just snaps into place.
        requestAnimationFrame(() => {
            requestAnimationFrame(() => {
                elements.menu.classList.add('is-open');
                elements.backdrop.classList.add('is-open');
            });
        });
    };

    const closeMenu = () => {
        elements.menu.classList.remove('is-open');
        elements.backdrop.classList.remove('is-open');
        document.body.classList.remove('vehicle-menu-open');

        window.clearTimeout(closeTimer);
        closeTimer = window.setTimeout(() => {
            elements.menu.hidden = true;
            elements.backdrop.hidden = true;
        }, CLOSE_ANIM_MS);
    };

    elements.closeButton.addEventListener('click', () => post('vehiclemenu_close'));

    document.addEventListener('keydown', (event) => {
        if (event.key === 'Escape' && !elements.menu.hidden) {
            post('vehiclemenu_close');
        }
    });

    window.addEventListener('message', ({ data }) => {
        if (data.action === 'vehicleMenuOpen') {
            openMenu(data.state || {});
        } else if (data.action === 'vehicleMenuState') {
            if (!elements.menu.hidden) render(data.state || {});
        } else if (data.action === 'vehicleMenuClose') {
            closeMenu();
        }
    });
})();
