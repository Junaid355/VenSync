/**
 * VenSync - Discord & Vencord Auto-Setup Suite - Frontend Logic
 */

let isBusy = false;

// DOM Elements
const badgeElement = document.getElementById('system-badge');
const badgeText = document.getElementById('badge-text');
const btnRefresh = document.getElementById('btn-refresh');

const discordPathText = document.getElementById('discord-path-text');
const discordStatusPill = document.getElementById('discord-status-pill');
const discordRunningText = document.getElementById('discord-running-text');

const vencordSubText = document.getElementById('vencord-sub-text');
const vencordStatusPill = document.getElementById('vencord-status-pill');
const vencordStateText = document.getElementById('vencord-state-text');

const startupToggle = document.getElementById('startup-toggle');
const btnAutoSetup = document.getElementById('btn-auto-setup');
const btnLaunchDiscord = document.getElementById('btn-launch-discord');
const btnRepairVencord = document.getElementById('btn-repair-vencord');
const btnInstallVencord = document.getElementById('btn-install-vencord');
const btnKillDiscord = document.getElementById('btn-kill-discord');

const logTerminal = document.getElementById('log-terminal');
const btnClearLogs = document.getElementById('btn-clear-logs');
const footerTime = document.getElementById('footer-time');

// Logger
function appendLog(message, level = 'info') {
    const line = document.createElement('div');
    line.className = `log-line log-${level}`;
    const timestamp = new Date().toLocaleTimeString();
    line.textContent = `[${timestamp}] ${message}`;
    logTerminal.appendChild(line);
    logTerminal.scrollTop = logTerminal.scrollHeight;
}

window.receiveBackendLog = function(message, level) {
    appendLog(message, level || 'info');
};

window.receiveBackendStatus = function(statusJson) {
    const status = typeof statusJson === 'string' ? JSON.parse(statusJson) : statusJson;
    renderStatus(status);
};

window.onActionCompleted = function() {
    setBusyState(false);
    appendLog('Action completed.', 'success');
};

function renderStatus(status) {
    if (!status) return;

    const discord = status.discord || {};
    const vencord = status.vencord || {};
    const system = status.system || {};

    // Discord Card
    if (discord.installed) {
        discordPathText.textContent = discord.path || 'Installed';
        discordStatusPill.className = 'pill pill-ready';
        discordStatusPill.textContent = 'Installed';
        discordRunningText.textContent = discord.running ? '🟢 Active & Running' : '⚪ Stopped';
    } else {
        discordPathText.textContent = 'Not Installed';
        discordStatusPill.className = 'pill pill-missing';
        discordStatusPill.textContent = 'Missing';
        discordRunningText.textContent = 'No';
    }

    // Vencord Card
    if (vencord.patched) {
        vencordSubText.textContent = 'Injected & Active';
        vencordStatusPill.className = 'pill pill-ready';
        vencordStatusPill.textContent = 'Patched';
        vencordStateText.textContent = '✅ Patched into Discord';
    } else {
        vencordSubText.textContent = 'Unpatched / Needs Hook';
        vencordStatusPill.className = 'pill pill-missing';
        vencordStatusPill.textContent = 'Unpatched';
        vencordStateText.textContent = '❌ Patch Missing';
    }

    // Badge
    if (discord.installed && vencord.patched) {
        badgeElement.className = 'badge badge-success';
        badgeText.textContent = 'All Systems Ready';
    } else if (!discord.installed) {
        badgeElement.className = 'badge badge-danger';
        badgeText.textContent = 'Discord Missing';
    } else {
        badgeElement.className = 'badge badge-warning';
        badgeText.textContent = 'Patch Required';
    }

    startupToggle.checked = !!system.startup_enabled;
    footerTime.textContent = `Last Checked: ${new Date().toLocaleTimeString()}`;
}

function waitForApi() {
    return new Promise((resolve) => {
        if (window.pywebview && window.pywebview.api) {
            return resolve(window.pywebview.api);
        }
        let attempts = 0;
        const interval = setInterval(() => {
            attempts++;
            if (window.pywebview && window.pywebview.api) {
                clearInterval(interval);
                resolve(window.pywebview.api);
            } else if (attempts > 50) {
                clearInterval(interval);
                resolve(null);
            }
        }, 100);
    });
}

async function callApi(method, ...args) {
    const api = await waitForApi();
    if (api && typeof api[method] === 'function') {
        try {
            return await api[method](...args);
        } catch (err) {
            appendLog(`API Error (${method}): ${err}`, 'error');
            setBusyState(false);
            return null;
        }
    } else {
        appendLog(`Backend API not connected yet for ${method}.`, 'warning');
        setBusyState(false);
        return null;
    }
}

async function refreshStatus() {
    appendLog('Checking system diagnostics...', 'info');
    const status = await callApi('get_status');
    if (status) {
        renderStatus(status);
        appendLog('Diagnostics updated.', 'success');
    }
}

function setBusyState(busy, btnElement = null) {
    isBusy = busy;
    if (btnElement) {
        if (busy) {
            btnElement.classList.add('is-loading');
        } else {
            btnElement.classList.remove('is-loading');
        }
    } else {
        btnAutoSetup.classList.remove('is-loading');
    }

    const allButtons = document.querySelectorAll('.action-btn, .btn');
    allButtons.forEach(btn => {
        btn.disabled = busy;
        btn.style.opacity = busy ? '0.6' : '1';
    });
}

// Handlers
btnAutoSetup.addEventListener('click', async () => {
    if (isBusy) return;
    setBusyState(true, btnAutoSetup);
    appendLog('Starting 1-Click Complete Auto Setup...', 'info');
    await callApi('auto_setup_all');
});

btnLaunchDiscord.addEventListener('click', async () => {
    if (isBusy) return;
    appendLog('Launching Discord...', 'info');
    await callApi('launch_discord');
});

btnRepairVencord.addEventListener('click', async () => {
    if (isBusy) return;
    setBusyState(true);
    appendLog('Repairing Vencord hook...', 'info');
    await callApi('repair_vencord');
});

btnInstallVencord.addEventListener('click', async () => {
    if (isBusy) return;
    setBusyState(true);
    appendLog('Installing Vencord...', 'info');
    await callApi('install_vencord');
});

btnKillDiscord.addEventListener('click', async () => {
    if (isBusy) return;
    appendLog('Stopping Discord processes...', 'info');
    await callApi('kill_discord');
});

startupToggle.addEventListener('change', async (e) => {
    const isChecked = e.target.checked;
    appendLog(`Setting Windows Startup Auto-Check to ${isChecked ? 'Enabled' : 'Disabled'}...`, 'info');
    await callApi('set_startup_enabled', isChecked);
});

btnRefresh.addEventListener('click', refreshStatus);

btnClearLogs.addEventListener('click', () => {
    logTerminal.innerHTML = '<div class="log-line log-info">[System] Logs cleared.</div>';
});

window.addEventListener('pywebviewready', () => {
    appendLog('PyWebView bridge connected.', 'success');
    refreshStatus();
});

setTimeout(refreshStatus, 300);
