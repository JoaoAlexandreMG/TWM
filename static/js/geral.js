document.addEventListener("DOMContentLoaded", function () {
  const closeBtn = document.querySelector(".close-btn-alert");
  if (closeBtn) {
    closeBtn.onclick = function () {
      document.getElementById("customAlert").style.display = "none";
    };
  }
});

window.onclick = function (event) {
  const modal = document.getElementById("customAlert");
  if (event.target === modal) {
    modal.style.display = "none";
  }
};

function showCustomAlert(message, type) {
  Swal.fire({
    title: "Atenção!",
    text: message,
    icon: type, //'success', 'error', 'info', 'warning'
    confirmButtonText: "Ok",
    confirmButtonColor: "#007bff",
  });
}
function showConfirmDialog(message) {
  return new Promise((resolve) => {
    Swal.fire({
      title: "Atenção!",
      text: message,
      icon: "question",
      showCancelButton: true,
      confirmButtonText: "Sim",
      cancelButtonText: "Cancelar",
      confirmButtonColor: "#007bff",
      cancelButtonColor: "#dc3545",
    }).then((result) => {
      resolve(result.value);
    });
  });
}
function closePopup(id) {
  document.getElementById(id).style.display = "none";
}
function showPopup(id) {
  document.getElementById(id).style.display = "flex";
}
function togglePopup() {
  const registerPopup = document.getElementById("register-popup");
  const loginPopup = document.getElementById("login-popup");

  if (registerPopup.style.display === "none" || !registerPopup.style.display) {
    registerPopup.style.display = "block";
    loginPopup.style.display = "none";
  } else {
    registerPopup.style.display = "none";
    loginPopup.style.display = "block";
  }
}
