(() => {
    'use strict';

    const AUTO_HIDE_MS = 20000;
    const HIDE_ANIM_MS = 450;

    const elements = {
        hints: document.getElementById('vehicle-hints'),
        engineLabel: document.getElementById('vehicle-hints-engine-label'),
        lockLabel: document.getElementById('vehicle-hints-lock-label')
    };

    let autoHideTimer = null;
    let hiddenTimer = null;

    const show = () => {
        window.clearTimeout(autoHideTimer);
        window.clearTimeout(hiddenTimer);

        elements.hints.hidden = false;
        elements.hints.classList.remove('is-leaving', 'engine-on');
        elements.hints.classList.add('is-entering');
        document.body.classList.add('vehicle-hints-visible');

        requestAnimationFrame(() => {
            requestAnimationFrame(() => {
                elements.hints.classList.remove('is-entering');
            });
        });

        autoHideTimer = window.setTimeout(hide, AUTO_HIDE_MS);
    };

    const hide = () => {
        window.clearTimeout(autoHideTimer);
        elements.hints.classList.add('is-leaving');
        document.body.classList.remove('vehicle-hints-visible');

        hiddenTimer = window.setTimeout(() => {
            elements.hints.hidden = true;
            elements.hints.classList.remove('is-leaving', 'engine-on');
        }, HIDE_ANIM_MS);
    };

    window.addEventListener('message', ({ data }) => {
        if (data.action === 'vehicleHintsShow') {
            show();
        } else if (data.action === 'updateVehicleHud') {
            elements.hints.classList.toggle('engine-on', Boolean(data.engineOn));
            elements.engineLabel.textContent = data.engineOn ? 'STOP ENGINE' : 'START ENGINE';
            elements.lockLabel.textContent = data.locked ? 'UNLOCK' : 'LOCK';
        } else if (data.action === 'hideVehicleHud') {
            window.clearTimeout(autoHideTimer);
            window.clearTimeout(hiddenTimer);
            elements.hints.hidden = true;
            elements.hints.classList.remove('is-entering', 'is-leaving', 'engine-on');
            document.body.classList.remove('vehicle-hints-visible');
        }
    });
})();
