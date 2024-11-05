function submitLoginForm() {
  const email = document.getElementById("email").value;
  const password = document.getElementById("password").value;

  const data = {
    email: email,
    password: password,
  };
  

  fetch("/login", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(data),
  })
    .then((response) => response.json())
    .then((data) => {
      if (data.status === "success") {
        window.location.href = "/dashboard";
      } else {
        showCustomAlert(data.message, "error");
      }
    })
    .catch((error) => {
      console.error("Erro:", error);
      alert("Ocorreu um erro ao tentar fazer login.");
    });
}
