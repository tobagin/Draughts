/**
 * dashboard.js
 *
 * Renders the server statistics dashboard (HTML) for the /stats endpoint.
 * Presentation-only: it receives a plain data context and returns a string,
 * so it has no dependency on the live server state or Supabase. All dynamic
 * values are HTML-escaped (or embedded via a script-safe JSON helper) to
 * defend against stored XSS from client-supplied variant/player names.
 */

'use strict';

/**
 * Escape a value for safe interpolation into HTML.
 */
function escapeHtml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/**
 * Serialize a value for safe embedding inside an inline <script> block.
 * JSON.stringify alone does not neutralize "</script>" or the JS line
 * separators U+2028/U+2029, so escape those code points too.
 */
function jsonForScript(value) {
  return JSON.stringify(value)
    .replace(/</g, '\\u003c')
    .replace(/>/g, '\\u003e')
    .replace(/\u2028/g, '\\u2028')
    .replace(/\u2029/g, '\\u2029');
}

function renderDashboard(context) {
  const {
    stats,
    supabaseEnabled,
    clientsCount,
    roomsCount,
    serverVersion,
    supabaseStats,
    supabaseVariantStats
  } = context;

  const uptime = Math.floor((Date.now() - stats.startTime) / 1000);
  const days = Math.floor(uptime / 86400);
  const hours = Math.floor((uptime % 86400) / 3600);
  const minutes = Math.floor((uptime % 3600) / 60);
  const uptimeStr = `${days}d ${hours}h ${minutes}m`;

  // Prefer all-time Supabase totals when available, else the in-memory session stats
  const totalGames = supabaseStats ? (supabaseStats.total_games || 0) : stats.totalGames;

  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Draughts Server Statistics</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: #333;
      padding: 20px;
      min-height: 100vh;
    }
    .container {
      max-width: 1200px;
      margin: 0 auto;
    }
    h1 {
      color: white;
      text-align: center;
      margin-bottom: 30px;
      font-size: 2.5rem;
      text-shadow: 2px 2px 4px rgba(0,0,0,0.2);
    }
    .stats-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
      gap: 20px;
      margin-bottom: 30px;
    }
    .stat-card {
      background: white;
      padding: 25px;
      border-radius: 12px;
      box-shadow: 0 4px 6px rgba(0,0,0,0.1);
      transition: transform 0.2s;
    }
    .stat-card:hover {
      transform: translateY(-5px);
      box-shadow: 0 8px 12px rgba(0,0,0,0.15);
    }
    .stat-value {
      font-size: 2.5rem;
      font-weight: bold;
      color: #667eea;
      margin-bottom: 5px;
    }
    .stat-label {
      color: #666;
      font-size: 0.9rem;
      text-transform: uppercase;
      letter-spacing: 1px;
    }
    .chart-card {
      background: white;
      padding: 25px;
      border-radius: 12px;
      box-shadow: 0 4px 6px rgba(0,0,0,0.1);
      margin-bottom: 20px;
    }
    h2 {
      color: #333;
      margin-bottom: 20px;
      font-size: 1.5rem;
    }
    table {
      width: 100%;
      border-collapse: collapse;
    }
    th, td {
      padding: 12px;
      text-align: left;
      border-bottom: 1px solid #eee;
    }
    th {
      background: #f8f9fa;
      color: #667eea;
      font-weight: 600;
    }
    tr:hover {
      background: #f8f9fa;
    }
    .info-banner {
      background: rgba(255, 255, 255, 0.95);
      color: #333;
      padding: 15px 25px;
      border-radius: 8px;
      margin-bottom: 20px;
      text-align: center;
      font-weight: 500;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    .status-indicator {
      display: inline-block;
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: #10b981;
      margin-right: 8px;
      animation: pulse 2s infinite;
    }
    @keyframes pulse {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.5; }
    }
    .footer {
      text-align: center;
      color: white;
      margin-top: 30px;
      opacity: 0.8;
    }
    .pie-chart {
      display: flex;
      justify-content: center;
      align-items: center;
      margin: 20px 0;
    }
  </style>
  <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
  <script>
    // Auto-refresh every 30 seconds (increased to let charts render)
    setTimeout(() => location.reload(), 30000);
  </script>
</head>
<body>
  <div class="container">
    <h1><span class="status-indicator"></span>Draughts Multiplayer Server</h1>

    ${supabaseEnabled ? '<div class="info-banner">📊 Stats powered by Supabase (all-time data)</div>' : '<div class="info-banner">⚠️ In-memory stats only (current session)</div>'}

    <div class="stats-grid">
      <div class="stat-card">
        <div class="stat-value">${totalGames}</div>
        <div class="stat-label">Total Games</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${stats.activeGames}</div>
        <div class="stat-label">Active Games</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${supabaseStats ? totalGames - stats.activeGames : stats.completedGames}</div>
        <div class="stat-label">Completed Games</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${clientsCount}</div>
        <div class="stat-label">Connected Players</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${stats.totalConnections}</div>
        <div class="stat-label">Connections (Session)</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${stats.totalConnectionsAllTime.toLocaleString()}</div>
        <div class="stat-label">Connections (All-Time)</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${stats.peakConcurrentGames}</div>
        <div class="stat-label">Peak Games (Session)</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${stats.peakConcurrentGamesAllTime}</div>
        <div class="stat-label">Peak Games (All-Time)</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${uptimeStr}</div>
        <div class="stat-label">Uptime</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${roomsCount}</div>
        <div class="stat-label">Active Rooms</div>
      </div>
    </div>

    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(500px, 1fr)); gap: 20px; margin-bottom: 20px;">
      <div class="chart-card">
        <h2>Games by Variant</h2>
        ${totalGames > 0 ? '<canvas id="variantChart" style="max-height: 300px;"></canvas>' : '<p style="text-align: center; color: #999;">No games played yet</p>'}
      </div>

      <div class="chart-card">
        <h2>Game Results Distribution</h2>
        ${totalGames > 0 ? '<canvas id="resultsChart" style="max-height: 300px;"></canvas>' : '<p style="text-align: center; color: #999;">No games played yet</p>'}
      </div>
    </div>

    <div class="chart-card">
      <h2>Win Rate Comparison</h2>
      ${totalGames > 0 ? '<canvas id="winRateChart" style="max-height: 250px;"></canvas>' : '<p style="text-align: center; color: #999;">No games played yet</p>'}
    </div>

    <div class="chart-card">
      <h2>Connection Statistics</h2>
      <canvas id="connectionChart" style="max-height: 250px;"></canvas>
    </div>

    <div class="footer">
      <p>Server Version ${escapeHtml(serverVersion)} | Auto-refreshes every 30 seconds</p>
    </div>
  </div>

  <script>
    // Prepare data
    const totalGames = ${totalGames};
    const redWins = ${supabaseStats ? (supabaseStats.red_wins || 0) : stats.gamesByResult.red_wins};
    const blackWins = ${supabaseStats ? (supabaseStats.black_wins || 0) : stats.gamesByResult.black_wins};
    const draws = ${supabaseStats ? (supabaseStats.draws || 0) : stats.gamesByResult.draw};
    const resignations = ${supabaseStats ? (supabaseStats.resignations || 0) : stats.gamesByResult.resignation};
    const timeouts = ${supabaseStats ? (supabaseStats.timeouts || 0) : (stats.gamesByResult.timeout || 0)};

    // Variant data
    const variantData = ${jsonForScript(
      supabaseVariantStats && supabaseVariantStats.length > 0
        ? supabaseVariantStats.map(v => ({ variant: v.variant, count: v.game_count }))
        : Object.entries(stats.gamesByVariant).map(([variant, count]) => ({ variant, count }))
    )};

    // Chart.js default config
    Chart.defaults.font.family = '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen, Ubuntu, Cantarell, sans-serif';
    Chart.defaults.responsive = true;
    Chart.defaults.maintainAspectRatio = true;

    // Color palette
    const colors = {
      purple: '#667eea',
      pink: '#764ba2',
      blue: '#3b82f6',
      green: '#10b981',
      yellow: '#f59e0b',
      red: '#ef4444',
      orange: '#f97316',
      teal: '#14b8a6',
      indigo: '#6366f1'
    };

    if (totalGames > 0) {
      // 1. Variant Distribution (Doughnut Chart)
      const variantCtx = document.getElementById('variantChart');
      if (variantCtx) {
        new Chart(variantCtx, {
          type: 'doughnut',
          data: {
            labels: variantData.map(v => v.variant),
            datasets: [{
              data: variantData.map(v => v.count),
              backgroundColor: [
                colors.purple,
                colors.blue,
                colors.green,
                colors.yellow,
                colors.red,
                colors.orange,
                colors.teal,
                colors.indigo
              ],
              borderWidth: 2,
              borderColor: '#fff'
            }]
          },
          options: {
            plugins: {
              legend: {
                position: 'bottom',
                labels: {
                  padding: 15,
                  font: { size: 12 }
                }
              },
              tooltip: {
                callbacks: {
                  label: function(context) {
                    const label = context.label || '';
                    const value = context.parsed;
                    const percentage = ((value / totalGames) * 100).toFixed(1);
                    return label + ': ' + value + ' (' + percentage + '%)';
                  }
                }
              }
            }
          }
        });
      }

      // 2. Game Results Distribution (Pie Chart)
      const resultsCtx = document.getElementById('resultsChart');
      if (resultsCtx) {
        new Chart(resultsCtx, {
          type: 'pie',
          data: {
            labels: ['Red Wins', 'Black Wins', 'Draws', 'Resignations', 'Timeouts'],
            datasets: [{
              data: [redWins, blackWins, draws, resignations, timeouts],
              backgroundColor: [
                colors.red,
                '#1f2937',
                colors.yellow,
                colors.orange,
                colors.purple
              ],
              borderWidth: 2,
              borderColor: '#fff'
            }]
          },
          options: {
            plugins: {
              legend: {
                position: 'bottom',
                labels: {
                  padding: 15,
                  font: { size: 12 }
                }
              },
              tooltip: {
                callbacks: {
                  label: function(context) {
                    const label = context.label || '';
                    const value = context.parsed;
                    const percentage = ((value / totalGames) * 100).toFixed(1);
                    return label + ': ' + value + ' (' + percentage + '%)';
                  }
                }
              }
            }
          }
        });
      }

      // 3. Win Rate Comparison (Horizontal Bar Chart)
      const winRateCtx = document.getElementById('winRateChart');
      if (winRateCtx) {
        const totalDecisiveGames = redWins + blackWins;
        const redWinRate = totalDecisiveGames > 0 ? ((redWins / totalDecisiveGames) * 100).toFixed(1) : 0;
        const blackWinRate = totalDecisiveGames > 0 ? ((blackWins / totalDecisiveGames) * 100).toFixed(1) : 0;

        new Chart(winRateCtx, {
          type: 'bar',
          data: {
            labels: ['Red Win Rate', 'Black Win Rate', 'Draw Rate'],
            datasets: [{
              label: 'Percentage',
              data: [
                redWinRate,
                blackWinRate,
                totalGames > 0 ? ((draws / totalGames) * 100).toFixed(1) : 0
              ],
              backgroundColor: [colors.red, '#1f2937', colors.yellow],
              borderColor: [colors.red, '#1f2937', colors.yellow],
              borderWidth: 2
            }]
          },
          options: {
            indexAxis: 'y',
            scales: {
              x: {
                beginAtZero: true,
                max: 100,
                ticks: {
                  callback: function(value) {
                    return value + '%';
                  }
                }
              }
            },
            plugins: {
              legend: {
                display: false
              },
              tooltip: {
                callbacks: {
                  label: function(context) {
                    return context.parsed.x + '%';
                  }
                }
              }
            }
          }
        });
      }
    }

    // 4. Connection Statistics (Bar Chart)
    const connectionCtx = document.getElementById('connectionChart');
    if (connectionCtx) {
      new Chart(connectionCtx, {
        type: 'bar',
        data: {
          labels: ['Session Connections', 'All-Time Connections', 'Session Peak Games', 'All-Time Peak Games'],
          datasets: [{
            label: 'Count',
            data: [
              ${stats.totalConnections},
              ${stats.totalConnectionsAllTime},
              ${stats.peakConcurrentGames},
              ${stats.peakConcurrentGamesAllTime}
            ],
            backgroundColor: [colors.blue, colors.purple, colors.green, colors.teal],
            borderColor: [colors.blue, colors.purple, colors.green, colors.teal],
            borderWidth: 2
          }]
        },
        options: {
          scales: {
            y: {
              beginAtZero: true
            }
          },
          plugins: {
            legend: {
              display: false
            }
          }
        }
      });
    }
  </script>
</body>
</html>
  `;
}

module.exports = { renderDashboard, escapeHtml, jsonForScript };
