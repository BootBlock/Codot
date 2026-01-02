import * as vscode from 'vscode';
import { WebSocketServer, WebSocket } from 'ws';

let server: WebSocketServer | null = null;
let clients: Set<WebSocket> = new Set();
let statusBarItem: vscode.StatusBarItem;

export function activate(context: vscode.ExtensionContext) {
    console.log('Codot Bridge extension is now active');

    // Create status bar item
    statusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
    statusBarItem.command = 'codot-bridge.status';
    context.subscriptions.push(statusBarItem);

    // Register commands
    context.subscriptions.push(
        vscode.commands.registerCommand('codot-bridge.start', startServer),
        vscode.commands.registerCommand('codot-bridge.stop', stopServer),
        vscode.commands.registerCommand('codot-bridge.status', showStatus)
    );

    // Auto-start if configured
    const config = vscode.workspace.getConfiguration('codot-bridge');
    if (config.get('autoStart', true)) {
        startServer();
    }

    // Cleanup on deactivation
    context.subscriptions.push({
        dispose: () => {
            stopServer();
        }
    });
}

export function deactivate() {
    stopServer();
}

function startServer() {
    if (server) {
        vscode.window.showInformationMessage('Codot Bridge server is already running');
        return;
    }

    const config = vscode.workspace.getConfiguration('codot-bridge');
    const port = config.get<number>('port', 6851);

    try {
        server = new WebSocketServer({ port });

        server.on('connection', (ws: WebSocket) => {
            console.log('Godot client connected');
            clients.add(ws);
            updateStatusBar();

            // Send acknowledgment
            ws.send(JSON.stringify({ type: 'connected', message: 'Connected to VS Code Codot Bridge' }));

            ws.on('message', async (data: Buffer) => {
                try {
                    const message = JSON.parse(data.toString());
                    await handleMessage(ws, message);
                } catch (err) {
                    console.error('Error parsing message:', err);
                    ws.send(JSON.stringify({ type: 'error', message: 'Invalid JSON' }));
                }
            });

            ws.on('close', () => {
                console.log('Godot client disconnected');
                clients.delete(ws);
                updateStatusBar();
            });

            ws.on('error', (err) => {
                console.error('WebSocket error:', err);
                clients.delete(ws);
                updateStatusBar();
            });
        });

        server.on('error', (err) => {
            console.error('Server error:', err);
            vscode.window.showErrorMessage(`Codot Bridge server error: ${err.message}`);
            server = null;
            updateStatusBar();
        });

        console.log(`Codot Bridge server started on port ${port}`);
        vscode.window.showInformationMessage(`Codot Bridge server started on port ${port}`);
        updateStatusBar();

    } catch (err) {
        console.error('Failed to start server:', err);
        vscode.window.showErrorMessage(`Failed to start Codot Bridge server: ${err}`);
    }
}

function stopServer() {
    if (!server) {
        return;
    }

    // Close all client connections
    for (const client of clients) {
        client.close();
    }
    clients.clear();

    server.close();
    server = null;

    console.log('Codot Bridge server stopped');
    vscode.window.showInformationMessage('Codot Bridge server stopped');
    updateStatusBar();
}

function showStatus() {
    const isRunning = server !== null;
    const clientCount = clients.size;

    if (isRunning) {
        const config = vscode.workspace.getConfiguration('codot-bridge');
        const port = config.get<number>('port', 6851);
        vscode.window.showInformationMessage(
            `Codot Bridge: Running on port ${port} with ${clientCount} client(s) connected`
        );
    } else {
        vscode.window.showInformationMessage('Codot Bridge: Not running');
    }
}

function updateStatusBar() {
    if (server) {
        statusBarItem.text = `$(plug) Codot: ${clients.size} connected`;
        statusBarItem.tooltip = 'Codot Bridge server is running. Click for status.';
        statusBarItem.backgroundColor = undefined;
    } else {
        statusBarItem.text = '$(debug-disconnect) Codot: Off';
        statusBarItem.tooltip = 'Codot Bridge server is not running. Click for status.';
        statusBarItem.backgroundColor = new vscode.ThemeColor('statusBarItem.warningBackground');
    }
    statusBarItem.show();
}

async function handleMessage(ws: WebSocket, message: any) {
    const type = message.type;

    switch (type) {
        case 'prompt':
            await handlePrompt(ws, message);
            break;

        case 'ping':
            ws.send(JSON.stringify({ type: 'pong', timestamp: Date.now() }));
            break;

        default:
            console.log('Unknown message type:', type);
            ws.send(JSON.stringify({ type: 'error', message: `Unknown message type: ${type}` }));
    }
}

async function handlePrompt(ws: WebSocket, message: any) {
    // Support both old 'prompt' field and new 'content' field with 'title'
    const title: string = message.title || '';
    const content: string = message.content || message.prompt || message.body || '';
    const promptId: string = message.prompt_id || '';

    if (!content) {
        ws.send(JSON.stringify({ type: 'error', success: false, message: 'Empty prompt content' }));
        return;
    }

    console.log(`Received prompt from Godot: "${title}" - ${content.substring(0, 100)}...`);

    // Build a context-aware prompt
    let fullPrompt = content;
    
    // Prepend title if provided
    if (title) {
        fullPrompt = `# ${title}\n\n${content}`;
    }

    // Add context about current scene if available
    const context = message.context || {};
    if (context.current_scene) {
        fullPrompt = `[Context: Working in Godot project, current scene: ${context.current_scene}]\n\n${fullPrompt}`;
    }

    // Add selected nodes context
    if (context.selected_nodes && context.selected_nodes.length > 0) {
        fullPrompt = `[Selected nodes: ${context.selected_nodes.join(', ')}]\n\n${fullPrompt}`;
    }

    try {
        // Method 1: Try to use GitHub Copilot Chat API (if available)
        const copilotExtension = vscode.extensions.getExtension('github.copilot-chat');
        
        if (copilotExtension) {
            // Open Copilot Chat and send the prompt
            await vscode.commands.executeCommand('workbench.panel.chat.view.copilot.focus');
            
            // Small delay to ensure panel is focused
            await new Promise(resolve => setTimeout(resolve, 200));
            
            // Insert the prompt into the chat input
            // We use the insertSnippet approach via the chat input
            await vscode.commands.executeCommand('workbench.action.chat.open', {
                query: fullPrompt
            });

            ws.send(JSON.stringify({ 
                type: 'ack',
                success: true,
                message: 'Prompt sent to Copilot Chat',
                prompt_id: promptId,
                title: title.substring(0, 100)
            }));

        } else {
            // Fallback: Show the prompt in an input box for manual handling
            vscode.window.showInputBox({
                prompt: 'Prompt from Godot (Copilot Chat not available)',
                value: fullPrompt,
                ignoreFocusOut: true
            }).then(async (value) => {
                if (value) {
                    // Copy to clipboard as fallback
                    await vscode.env.clipboard.writeText(value);
                    vscode.window.showInformationMessage('Prompt copied to clipboard');
                }
            });

            ws.send(JSON.stringify({ 
                type: 'ack',
                success: true,
                message: 'Prompt shown in VS Code (Copilot not available)',
                prompt_id: promptId,
                title: title.substring(0, 100)
            }));
        }

    } catch (err) {
        console.error('Error handling prompt:', err);
        ws.send(JSON.stringify({ 
            type: 'error',
            success: false,
            message: `Error handling prompt: ${err}`,
            prompt_id: promptId
        }));
    }
}
