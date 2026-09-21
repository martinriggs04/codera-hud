(() => {
    'use strict';

    const elements = {
        hud: document.getElementById('dive-hud'),
        time: document.getElementById('dive-time'),
        depth: document.getElementById('dive-depth'),
        tankValue: document.getElementById('dive-tank-value'),
        tankFill: document.getElementById('dive-tank-fill')
    };

    const formatTime = (totalSeconds) => {
        const seconds = Math.max(0, Math.floor(Number(totalSeconds) || 0));
        const minutes = Math.floor(seconds / 60);
        const remainder = seconds % 60;
        return `${String(minutes).padStart(2, '0')}:${String(remainder).padStart(2, '0')}`;
    };

    const tankFillColor = (percent) => {
        if (percent >= 25) return '#ffffff';

        const dangerProgress = (25 - percent) / 25;
        const red = Math.round(255 + ((231 - 255) * dangerProgress));
        const green = Math.round(255 + ((76 - 255) * dangerProgress));
        const blue = Math.round(255 + ((60 - 255) * dangerProgress));
        return `rgb(${red}, ${green}, ${blue})`;
    };

    window.addEventListener('message', ({ data }) => {
        if (data.action !== 'diveHudUpdate') return;

        if (!data.visible) {
            elements.hud.style.display = 'none';
            return;
        }

        elements.hud.style.display = 'flex';
        elements.hud.classList.toggle('in-vehicle', Boolean(data.inVehicle));
        elements.time.textContent = formatTime(data.estSeconds);
        elements.depth.textContent = Number(data.depth || 0).toFixed(1);

        const tankMax = Number(data.tankMax) || 200;
        const tank = Math.max(0, Math.min(tankMax, Number(data.tank) || 0));
        const percent = (tank / tankMax) * 100;

        elements.tankValue.textContent = Math.round(tank);
        elements.tankFill.style.height = `${percent}%`;
        elements.tankFill.style.backgroundColor = tankFillColor(percent);
    });
})();
