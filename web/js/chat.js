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

    const elements = {
        hud: document.getElementById('player-hud'),
        input: document.getElementById('chat-input'),
        log: document.getElementById('chat-log'),
        suggestions: document.getElementById('chat-suggestions')
    };

    const MAX_LOG_ROWS = 15;
    const FADE_AFTER_MS = 25000;

    let isOpen = false;
    let suggestionList = []; // { name, help, params }
    let activeSuggestionIndex = -1;
    let history = [];
    let historyIndex = -1;
    let hideTimer = null;

    // The whole log hides together, 25s after the most recent message -
    // not each line on its own schedule. Never hides while chat is open.
    const armHideTimer = () => {
        window.clearTimeout(hideTimer);
        hideTimer = window.setTimeout(() => {
            if (!isOpen) elements.log.classList.add('is-idle');
        }, FADE_AFTER_MS);
    };

    const colorToCss = (color) => {
        if (Array.isArray(color) && color.length >= 3) {
            return `rgb(${color[0]}, ${color[1]}, ${color[2]})`;
        }
        return '#4fd1ff';
    };

    const escapeHtml = (value) => String(value)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;');

    const addLogRow = (message) => {
        const args = Array.isArray(message.args) ? message.args : [String(message.message || '')];
        const row = document.createElement('div');
        row.className = 'chat-log__row';

        if (args.length > 1) {
            const author = document.createElement('span');
            author.className = 'chat-log__author';
            author.style.color = colorToCss(message.color);
            author.textContent = `${args[0]}: `;
            row.appendChild(author);
            row.appendChild(document.createTextNode(args.slice(1).join(' ')));
        } else {
            row.textContent = args[0] || '';
        }

        elements.log.appendChild(row);

        while (elements.log.children.length > MAX_LOG_ROWS) {
            elements.log.removeChild(elements.log.firstChild);
        }

        elements.log.classList.remove('is-idle');
        armHideTimer();
    };

    const clearLog = () => {
        elements.log.innerHTML = '';
    };

    // Once the command name is fully typed (there's a space after it),
    // switch from "list of matching commands" to "detail view": the
    // command's own help on top, then every one of its parameters with
    // their own help text, highlighting whichever one is currently being
    // typed - same idea as the stock FiveM chat suggestion box.
    const renderDetail = (suggestion, activeParamIndex) => {
        const header = document.createElement('div');
        header.className = 'chat-suggestions__row chat-suggestions__row--header';

        const name = document.createElement('span');
        name.className = 'chat-suggestions__name';
        name.textContent = suggestion.name;

        const help = document.createElement('span');
        help.className = 'chat-suggestions__help';
        help.textContent = suggestion.help || '';

        header.appendChild(name);
        header.appendChild(help);
        elements.suggestions.appendChild(header);

        (suggestion.params || []).forEach((param, index) => {
            const row = document.createElement('div');
            row.className = 'chat-suggestions__param' + (index === activeParamIndex ? ' is-active' : '');

            const pname = document.createElement('span');
            pname.className = 'chat-suggestions__param-name';
            pname.textContent = param.name || `arg${index + 1}`;

            const phelp = document.createElement('span');
            phelp.className = 'chat-suggestions__param-help';
            phelp.textContent = param.help || '';

            row.appendChild(pname);
            row.appendChild(phelp);
            elements.suggestions.appendChild(row);
        });
    };

    const renderSuggestions = () => {
        elements.suggestions.innerHTML = '';
        elements.suggestions._matches = [];

        const value = elements.input.value;
        if (!value.startsWith('/')) {
            elements.suggestions.classList.remove('has-items');
            activeSuggestionIndex = -1;
            return;
        }

        const tokens = value.slice(1).split(' ');
        const term = tokens[0].toLowerCase();
        const typingArgs = value.includes(' ');

        const exactMatch = suggestionList.find((s) => s.name.slice(1).toLowerCase() === term);

        if (typingArgs && exactMatch) {
            renderDetail(exactMatch, tokens.length - 2);
            elements.suggestions._matches = [exactMatch];
            elements.suggestions.classList.add('has-items');
            return;
        }

        const matches = suggestionList
            .filter((s) => s.name.slice(1).toLowerCase().startsWith(term))
            .slice(0, 8);

        if (matches.length === 0) {
            elements.suggestions.classList.remove('has-items');
            activeSuggestionIndex = -1;
            return;
        }

        activeSuggestionIndex = Math.min(activeSuggestionIndex, matches.length - 1);

        matches.forEach((suggestion, index) => {
            const row = document.createElement('div');
            row.className = 'chat-suggestions__row' + (index === activeSuggestionIndex ? ' is-active' : '');

            const name = document.createElement('span');
            name.className = 'chat-suggestions__name';
            name.textContent = suggestion.name;

            const help = document.createElement('span');
            help.className = 'chat-suggestions__help';
            help.textContent = suggestion.help || '';

            row.appendChild(name);
            row.appendChild(help);
            row.addEventListener('mousedown', (event) => {
                event.preventDefault();
                elements.input.value = `${suggestion.name} `;
                elements.input.focus();
                renderSuggestions();
            });

            elements.suggestions.appendChild(row);
        });

        elements.suggestions._matches = matches;
        elements.suggestions.classList.add('has-items');
    };

    const openChat = () => {
        if (isOpen) return;
        isOpen = true;
        elements.hud.classList.add('chat-open');
        elements.input.value = '';
        historyIndex = -1;

        window.clearTimeout(hideTimer);
        elements.log.classList.remove('is-idle');

        window.setTimeout(() => elements.input.focus(), 40);
    };

    const closeChat = () => {
        if (!isOpen) return;
        isOpen = false;
        elements.hud.classList.remove('chat-open');
        elements.input.value = '';
        elements.input.blur();
        elements.suggestions.classList.remove('has-items');

        armHideTimer();
    };

    elements.input.addEventListener('input', renderSuggestions);

    elements.input.addEventListener('keydown', (event) => {
        const matches = elements.suggestions._matches || [];

        if (event.key === 'Enter') {
            event.preventDefault();
            const value = elements.input.value.trim();

            if (value !== '') {
                history.push(value);
                if (history.length > 50) history.shift();
            }

            post('chatResult', { message: value });
        } else if (event.key === 'Escape') {
            event.preventDefault();
            post('chatEscape', {});
        } else if (event.key === 'Tab' && matches.length > 0) {
            event.preventDefault();
            const pick = matches[Math.max(activeSuggestionIndex, 0)];
            elements.input.value = `${pick.name} `;
            renderSuggestions();
        } else if (event.key === 'ArrowDown') {
            if (matches.length > 0) {
                event.preventDefault();
                activeSuggestionIndex = (activeSuggestionIndex + 1) % matches.length;
                renderSuggestions();
            } else if (history.length > 0) {
                event.preventDefault();
                historyIndex = Math.max(historyIndex - 1, -1);
                elements.input.value = historyIndex === -1 ? '' : history[history.length - 1 - historyIndex];
            }
        } else if (event.key === 'ArrowUp') {
            if (matches.length > 0) {
                event.preventDefault();
                activeSuggestionIndex = (activeSuggestionIndex - 1 + matches.length) % matches.length;
                renderSuggestions();
            } else if (history.length > 0) {
                event.preventDefault();
                historyIndex = Math.min(historyIndex + 1, history.length - 1);
                elements.input.value = history[history.length - 1 - historyIndex];
            }
        }
    });

    window.addEventListener('message', ({ data }) => {
        if (data.action === 'chatOpen') {
            openChat();
        } else if (data.action === 'chatClose') {
            closeChat();
        } else if (data.action === 'chatAddMessage') {
            addLogRow(data.message || {});
        } else if (data.action === 'chatAddSuggestion') {
            const name = data.name;
            if (!name) return;

            const isGeneric = Boolean(data.generic);
            const existing = suggestionList.find((s) => s.name === name);

            // Never let the automatic "every registered command" sweep
            // overwrite a suggestion a resource already announced properly
            // (with real help text/params) via chat:addSuggestion.
            if (existing && !existing.generic && isGeneric) return;

            suggestionList = suggestionList.filter((s) => s.name !== name);
            suggestionList.push({ name, help: data.help || '', params: data.params || [], generic: isGeneric });
            renderSuggestions();
        } else if (data.action === 'chatRemoveSuggestion') {
            suggestionList = suggestionList.filter((s) => s.name !== data.name);
            renderSuggestions();
        } else if (data.action === 'chatClear') {
            clearLog();
        }
    });
})();
