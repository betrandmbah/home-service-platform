const API_BASE = "https://api.YOUR_DOMAIN";

async function callApi(path) {
  const res = await fetch(`${API_BASE}${path}`);
  const data = await res.json();
  document.getElementById("output").textContent = JSON.stringify(data, null, 2);
}

function loadUsers() { callApi("/users"); }
function loadBookings() { callApi("/bookings"); }
function loadWorkers() { callApi("/workers"); }
