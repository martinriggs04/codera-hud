(() => {
    'use strict';

    const elements = {
        hud: document.getElementById('player-hud'),
        health: document.getElementById('health-fill'),
        armor: document.getElementById('armor-fill'),
        hungerBar: document.getElementById('hunger-fill'),
        thirstBar: document.getElementById('thirst-fill'),
        stamina: document.getElementById('stamina-container'),
        staminaFill: document.getElementById('stamina-fill'),
        staminaIcon: document.getElementById('stamina-icon'),
        oxygen: document.getElementById('oxygen-container'),
        oxygenFill: document.getElementById('oxygen-fill'),
        oxygenIcon: document.getElementById('oxygen-icon'),
        mic: document.getElementById('player-mic'),
        micIcon: document.getElementById('player-mic-icon'),
        swimStaminaDivider: document.getElementById('swim-stamina-divider'),
        swimStaminaBadge: document.getElementById('swim-stamina-badge'),
        swimStaminaTicks: Array.from(document.querySelectorAll('#swim-stamina-ticks .swim-stamina-tick')),
        weapon: document.getElementById('weapon-hud'),
        ammoClip: document.getElementById('ammo-clip'),
        ammoTotal: document.getElementById('ammo-total'),
        crosshair: document.getElementById('crosshair'),
        cinematicTop: document.getElementById('cinematic-top'),
        cinematicBottom: document.getElementById('cinematic-bottom')
    };

    const clampPercent = (value) => Math.min(100, Math.max(0, Number(value) || 0));

    const getStaminaFillColor = (value) => {
        const stamina = clampPercent(value);
        if (stamina >= 25) return 'rgb(255, 255, 255)';

        const dangerProgress = (25 - stamina) / 25;
        const red = Math.round(255 + ((231 - 255) * dangerProgress));
        const green = Math.round(255 + ((76 - 255) * dangerProgress));
        const blue = Math.round(255 + ((60 - 255) * dangerProgress));

        return `rgb(${red}, ${green}, ${blue})`;
    };

    const HIDE_FADE_MS = 500;
    const hideTimers = new WeakMap();

    const setTemporaryBar = (
        container,
        fill,
        icon,
        visible,
        value,
        colorIconWhenLow = true,
        lowColor = '#e74c3c'
    ) => {
        if (visible) {
            window.clearTimeout(hideTimers.get(container));
            hideTimers.delete(container);
            container.style.display = 'flex';
            container.classList.remove('is-fading-out');

            const normalizedValue = clampPercent(value);
            fill.style.width = `${normalizedValue}%`;
            icon.style.color = colorIconWhenLow && normalizedValue < 20 ? lowColor : '#ffffff';
            return;
        }

        if (container.style.display === 'none' || hideTimers.has(container)) return;

        container.classList.add('is-fading-out');
        hideTimers.set(container, window.setTimeout(() => {
            container.style.display = 'none';
            container.classList.remove('is-fading-out');
            hideTimers.delete(container);
        }, HIDE_FADE_MS));
    };

    const updatePlayerHud = (data) => {
        elements.hud.style.display = 'flex';
        elements.health.style.width = `${data.health}%`;
        elements.armor.style.width = `${data.armor}%`;
        elements.health.classList.toggle('is-low', Number(data.health) < 20);
        elements.armor.classList.toggle('is-low', Number(data.armor) < 20);
        elements.hungerBar.style.width = `${data.hunger}%`;
        elements.thirstBar.style.width = `${data.thirst}%`;

        setTemporaryBar(
            elements.stamina,
            elements.staminaFill,
            elements.staminaIcon,
            Boolean(data.showStamina),
            data.stamina,
            false
        );
        elements.staminaFill.style.backgroundColor = getStaminaFillColor(data.stamina);
        setTemporaryBar(
            elements.oxygen,
            elements.oxygenFill,
            elements.oxygenIcon,
            data.isUnderwater,
            data.oxygen
        );

        const voiceMode = Math.min(3, Math.max(1, Number(data.voice) || 2));
        elements.mic.dataset.mode = String(voiceMode);
        elements.mic.classList.toggle('is-talking', Boolean(data.isTalking));
        elements.mic.classList.toggle('is-radio', Boolean(data.isRadio));

        const showSwimStamina = Boolean(data.showSwimStamina);
        elements.swimStaminaDivider.style.display = showSwimStamina ? 'block' : 'none';
        elements.swimStaminaBadge.style.display = showSwimStamina ? 'grid' : 'none';
        if (showSwimStamina) {
            const swimStamina = clampPercent(data.stamina);
            const litCount = Math.round(swimStamina / 10);
            const litColor = getStaminaFillColor(swimStamina);

            elements.swimStaminaTicks.forEach((tick, index) => {
                tick.style.backgroundColor = index < litCount ? litColor : '';
            });
        }

        elements.crosshair.style.display = data.isAiming ? 'block' : 'none';
        elements.weapon.style.display = data.hasWeapon ? 'flex' : 'none';

        if (data.hasWeapon) {
            elements.ammoClip.textContent = data.ammoClip;
            elements.ammoTotal.textContent = data.ammoTotal;
        }
    };

    const hidePlayerHud = () => {
        elements.hud.style.display = 'none';
        elements.stamina.style.display = 'none';
        elements.oxygen.style.display = 'none';
        elements.weapon.style.display = 'none';
        elements.crosshair.style.display = 'none';
    };

    window.addEventListener('message', ({ data }) => {
        if (data.action === 'updatePlayerHud') {
            updatePlayerHud(data.data);
        } else if (data.action === 'hidePlayerHud') {
            hidePlayerHud();
        } else if (data.action === 'cinematicBars') {
            const height = data.state ? '12vh' : '0';
            elements.cinematicTop.style.height = height;
            elements.cinematicBottom.style.height = height;
        }
    });
})();
