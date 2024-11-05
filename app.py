import hashlib
from flask import (
    Flask,
    redirect,
    request,
    jsonify,
    render_template,
    url_for,
    session,
)
import psycopg2
from psycopg2 import sql
from datetime import datetime
import requests


app = Flask(__name__)
app.secret_key = "supersecretkey"


DB_CONFIG = {
    "dbname": "pet_eletrica",
    "user": "postgres",
    "password": "2584",
    "host": "localhost",
    "port": "5432",
}


def get_db_connection():
    """
    Função para conectar ao banco de dados PostgreSQL
    Retorna um objeto connection da biblioteca psycopg2

    :return: Conexão com o banco de dados
    :rtype: psycopg2.extensions.connection
    """
    return psycopg2.connect(**DB_CONFIG)


@app.route("/", methods=["GET"])
def index():
    """
    Página principal do dashboard, acessível somente para usuários logados.
    Caso o usuário esteja logado, renderiza a página principal com o nome do usuário.
    Caso contrário, redireciona para a página de login.
    """
    if "user" in session:
        return render_template("dashboard.html")
    else:
        return render_template("login_e_cadastro.html")


@app.route("/<page>")
def render_page(page):
    """
    Função genérica para renderizar páginas.
    Caso o usuário esteja logado, renderiza a página especificada.
    Caso contrário, redireciona para a página de login.
    """
    if "user" in session:
        return render_template(page + ".html")
    else:
        return render_template("login_e_cadastro.html")


@app.route("/cadastrar_usuario", methods=["POST"])
def cadastrar_usuario():
    """
    Função para cadastrar um novo usuário no banco de dados.
    Recebe dados do formulário de cadastro via POST e insere um novo registro na tabela usuarios_painel.
    Verifica se o usuário já existe e retorna um erro caso positivo.
    Gera um hash da senha e salva na base.
    Salva o conteúdo da imagem de perfil como binário.
    Retorna uma resposta JSON com status e mensagem de erro caso ocorra algum problema.
    Caso contrário, salva o usuário na sessão e redireciona para a página principal.
    """
    foto_file = request.files.get("profile_picture")
    nome = request.form.get("name")
    email = request.form.get("email")
    senha = request.form.get("password")
    data_cadastro = datetime.now()

    conn = get_db_connection()
    cur = conn.cursor()
    try:
        cur.execute("SELECT COUNT(*) FROM usuarios_painel WHERE email = %s", (email,))
        if cur.fetchone()[0] > 0:
            return jsonify({"status": "error", "message": "Usuário já cadastrado"})

        hashed_password = hashlib.sha256(senha.encode()).hexdigest()

        foto_binaria = foto_file.read() if foto_file else None

        cur.execute(
            "INSERT INTO usuarios_painel (nome, email, senha, data_cadastro, imagem_perfil) VALUES (%s, %s, %s, %s, %s)",
            (nome, email, hashed_password, data_cadastro, foto_binaria),
        )
        conn.commit()
        session["user"] = email  # Salva o usuário na sessão
        return redirect(url_for("index"))
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)})
    finally:
        cur.close()
        conn.close()  # Certifique-se de fechar a conexão com o banco de dados


@app.route("/login", methods=["POST"])
def login():
    """Autentica um usuário e salva na sessão.

    Verifica se o email e senha informados são válidos e, caso sejam, salva o
    email na sessão e redireciona para a página principal.
    Retorna uma resposta JSON com status e mensagem de erro caso ocorra algum
    problema.
    """
    email = request.get_json().get("email")
    senha = request.get_json().get("password")

    # Verifique se a senha não é None
    if senha is None:
        return jsonify({"status": "error", "message": "A senha não pode ser vazia."})

    hashed_password = hashlib.sha256(senha.encode()).hexdigest()

    conn = get_db_connection()
    cur = conn.cursor()
    try:

        cur.execute(
            "SELECT COUNT(*) FROM usuarios_painel WHERE email = %s",
            (email,),
        )
        result1 = cur.fetchone()

        if result1[0] == 0:
            return jsonify({"status": "error", "message": "Usuário não cadastrado!"})
        cur.execute(
            "SELECT * FROM usuarios_painel WHERE email = %s AND senha = %s",
            (email, hashed_password),
        )
        result2 = cur.fetchone()
        if result2 is None:
            return jsonify({"status": "error", "message": "Senha inválida!"})

        session["user"] = email
        return jsonify({"status": "success", "message": "Login bem-sucedido"})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)})
    finally:
        cur.close()


@app.route("/logout")
def logout():
    """Remove o usuário da sessão e redireciona para a página de login.

    Essa rota é acessada quando o usuário clica no link de logout na barra de
    navegação. Se o usuário estiver logado (ou seja, se a sessão contiver o
    atributo "user"), remove o usuário da sessão e redireciona para a página
    principal. Caso contrário, redireciona para a página de login.
    """

    if "user" in session:
        session.pop("user", None)
        return render_template("login_e_cadastro.html")
    else:
        return render_template("login_e_cadastro.html")


@app.route("/contar_users", methods=["GET"])
def contar_users():
    """Conta o número de usuários cadastrados.

    Retorna uma resposta JSON com o status e a contagem de usuários. Caso
    o usuário não esteja logado, redireciona para a página de login.
    """
    if "user" in session:
        conn = get_db_connection()
        cur = conn.cursor()
        try:
            cur.execute("SELECT COUNT(*) FROM usuarios")
            result = cur.fetchone()
            return jsonify({"status": "success", "count": result[0]})
        except Exception as e:
            return jsonify({"status": "error", "message": str(e)})
        finally:
            cur.close()
            conn.close()
    else:
        return render_template("login_e_cadastro.html")


@app.route("/contar_itens", methods=["GET"])
def contar_itens():
    """Conta o número de itens únicos cadastrados.

    Retorna uma resposta JSON com o status e a contagem de itens. Caso
    o usuário não esteja logado, redireciona para a página de login.
    """
    if "user" in session:
        conn = get_db_connection()
        cur = conn.cursor()
        try:
            cur.execute("SELECT COUNT(DISTINCT nome) FROM itens")
            result = cur.fetchone()
            return jsonify({"status": "success", "count": result[0]})
        except Exception as e:
            return jsonify({"status": "error", "message": str(e)})
        finally:
            cur.close()
            conn.close()
    else:
        return render_template("login_e_cadastro.html")


@app.route("/contar_emprestimos_ativos", methods=["GET"])
def contar_emprestimos_ativos():
    """Conta o número de empréstimos ativos.

    Retorna uma resposta JSON com o status e a contagem de empréstimos
    ativos. Caso o usuário não esteja logado, redireciona para a página
    de login.
    """
    if "user" in session:
        conn = get_db_connection()
        cur = conn.cursor()
        try:
            cur.execute(
                """
                SELECT COUNT(*)
                FROM emprestimos_ativos
                """
            )
            result = cur.fetchone()
            return jsonify({"status": "success", "count": result[0]})
        except Exception as e:
            return jsonify({"status": "error", "message": str(e)})
        finally:
            cur.close()
            conn.close()
    else:
        return render_template("login_e_cadastro.html")


@app.route("/contar_emprestimos_atrasados", methods=["GET"])
def contar_emprestimos_atrasados():
    """Conta o número de empréstimos atrasados.

    Retorna uma resposta JSON com o status e a contagem de empréstimos
    atrasados. Caso o usuário não esteja logado, redireciona para a página
    de login.
    """
    if "user" in session:
        conn = get_db_connection()
        cur = conn.cursor()
        try:
            cur.execute(
                """
                SELECT COUNT(*)
                FROM emprestimos_atrasados
                """
            )

            result = cur.fetchone()
            return jsonify({"status": "success", "count": result[0]})
        except Exception as e:
            return jsonify({"status": "error", "message": str(e)})
        finally:
            cur.close()
            conn.close()
    else:
        return render_template("login_e_cadastro.html")


@app.route("/get_emprestimos_ativos", methods=["GET"])
def get_emprestimos_ativos():
    """Retorna uma lista de empréstimos ativos.

    Retorna uma lista de dicionários, onde cada dicionário representa um
    empréstimo ativo. Caso o usuário não esteja logado, redireciona para a
    página de login.

    Os dicionários possuem as seguintes chaves:
        - emprestimo_id: o ID do empréstimo
        - usuario_nome: o nome do usuário que fez o empréstimo
        - item_nome: o nome do item emprestado
        - item_qntd: a quantidade do item emprestado
        - data_emprestimo: a data em que o empréstimo foi feito
        - data_prevista_devolucao: a data prevista para a devolução do item

    A resposta é cacheada por 0 segundos, portanto a lista de empréstimos
    ativos é atualizada a cada requisição.
    """
    if "user" in session:
        conn = get_db_connection()
        cur = conn.cursor()
        try:
            cur.execute(
                """
                SELECT *
                FROM emprestimos_ativos
                """
            )
            emprestimos_ativos = cur.fetchall()

            return jsonify(
                [
                    {
                        "emprestimo_id": item[0],
                        "usuario_nome": item[1],
                        "item_nome": item[2],
                        "item_qntd": item[3],
                        "data_emprestimo": item[4].strftime("%d/%m/%Y"),
                        "data_prevista_devolucao": item[5].strftime("%d/%m/%Y"),
                    }
                    for item in emprestimos_ativos
                ]
            )
        except Exception as e:
            return jsonify({"status": "error", "message": str(e)})
        finally:
            cur.close()
            conn.close()
    else:
        return render_template("login_e_cadastro.html")


@app.route("/get_emprestimos_atrasados", methods=["GET"])
def get_emprestimos_atrasados():
    """
    Retorna uma lista de empréstimos atrasados.

    Retorna uma lista de dicionários, onde cada dicionário representa um
    empréstimo atrasado. Caso o usuário não esteja logado, redireciona para a
    página de login.

    Os dicionários possuem as seguintes chaves:
        - usuario_nome: o nome do usuário associado ao empréstimo
        - item_nome: o nome do item emprestado
        - item_qntd: a quantidade do item emprestado
        - data_emprestimo: a data em que o item foi emprestado
        - dias_atraso: a quantidade de dias de atraso do empréstimo

    A resposta é cacheada por 0 segundos, sendo atualizada a cada requisição.
    """
    if "user" in session:
        conn = get_db_connection()
        cur = conn.cursor()
        try:
            cur.execute("SELECT * FROM emprestimos_atrasados")
            emprestimos_atrasados = cur.fetchall()
            return jsonify(
                [
                    {
                        "emprestimo_id": item[0],
                        "usuario_nome": item[1],
                        "item_nome": item[2],
                        "item_qntd": item[3],
                        "data_emprestimo": item[4].strftime("%d/%m/%Y"),
                        "dias_atraso": item[5].days,
                    }
                    for item in emprestimos_atrasados
                ]
            )
        except Exception as e:
            return jsonify({"status": "error", "message": str(e)})
        finally:
            cur.close()
            conn.close()
    else:
        return render_template("login_e_cadastro.html")


@app.route("/get_historico_emprestimos", methods=["GET"])
def get_historico_emprestimos():
    """
    Retorna o histórico de empréstimos.

    A resposta é uma lista de dicionários, onde cada dicionário tem as seguintes chaves:
        - usuario_nome: nome do usuário que fez o empréstimo
        - item_nome: nome do item que foi emprestado
        - item_qntd: quantidade do item que foi emprestado
        - data_emprestimo: data em que o item foi emprestado
        - data_devolucao: data em que o item foi devolvido

    A resposta é cacheada por 0 segundos, sendo atualizada a cada requisição.
    """
    if "user" in session:
        conn = get_db_connection()
        cur = conn.cursor()
        try:
            cur.execute("SELECT * FROM emprestimos_historico")
            historico_emprestimos = cur.fetchall()
            return jsonify(
                [
                    {
                        "emprestimo_id": item[0],
                        "usuario_nome": item[1],
                        "item_nome": item[2],
                        "item_qntd": item[3],
                        "data_emprestimo": item[4].strftime("%d/%m/%Y"),
                        "data_devolucao": item[5].strftime("%d/%m/%Y"),
                    }
                    for item in historico_emprestimos
                ]
            )
        except Exception as e:
            return jsonify({"status": "error", "message": str(e)})
        finally:
            cur.close()
            conn.close()
    else:
        return render_template("login_e_cadastro.html")


@app.route("/add_item", methods=["POST"])
def add_item():
    """
    Adiciona um novo item ao estoque.

    A resposta é um JSON com as seguintes chaves:
        - status: "success" se o item foi adicionado com sucesso, "error" caso contrário
        - message: Uma mensagem de sucesso ou erro
    """
    if "user" in session:
        item_name = request.form["item_name"]
        item_quantity = request.form["item_quantity"]
        item_location = request.form["item_location"]

        conn = get_db_connection()
        cur = conn.cursor()
        try:
            cur.execute(
                "SELECT add_item(%s, %s, %s)",
                (item_name, item_location, item_quantity),
            )
            conn.commit()
            return jsonify(
                {"status": "success", "message": "Item adicionado com sucesso."}
            )
        except Exception as e:
            conn.rollback()
            return jsonify({"status": "error", "message": str(e)})
        finally:
            cur.close()
            conn.close()
    else:
        return render_template("login_e_cadastro.html")


@app.route("/add_user", methods=["POST"])
def add_user():
    """
    Adiciona um novo usuário ao banco de dados.

    A resposta é um JSON com as seguintes chaves:
        - status: "success" se o usuário foi adicionado com sucesso, "error" caso contrário
        - message: Uma mensagem de sucesso ou erro
    """
    if "user" in session:
        cpf = request.form["cpf"]
        nome = request.form["nome"]
        curso = request.form["curso"]
        email = request.form["email"]
        telefone = request.form["telefone"]
        url_validador = f"https://api.invertexto.com/v1/validator?token=15394|Zdb1z6WCCioetFrlm5NXYDQ2PpUiHiag&value={cpf}"
        response = requests.get(url_validador)
        if response.status_code == 200:
            data = response.json()
        if data["valid"]:
            conn = get_db_connection()
            cur = conn.cursor()
            try:
                cur.execute(
                    "SELECT add_user(%s, %s, %s, %s, %s)",
                    (cpf, nome, telefone, email, curso),
                )
                conn.commit()
                if cur.fetchone()[0]:
                    return jsonify(
                        {
                            "status": "success",
                            "message": "Usuário adicionado com sucesso",
                        }
                    )
                else:
                    return jsonify(
                        {
                            "status": "error",
                            "message": "CPF já cadastrado!",
                        }
                    )
            except Exception as e:
                conn.rollback()
                return jsonify({"status": "error", "message": str(e)})
            finally:
                cur.close()
                conn.close()
        else:
            return jsonify({"status": "error", "message": "CPF Inválido!"})
    else:
        return render_template("login_e_cadastro.html")


@app.route("/edit_user", methods=["POST"])
def edit_user():
    """
    Atualiza um usuário existente no banco de dados.

    A resposta é um JSON com as seguintes chaves:
        - status: "success" se o usuário foi atualizado com sucesso, "error" caso contrário
        - message: Uma mensagem de sucesso ou erro
    """
    if "user" in session:
        user_id = request.form.get("user_id")
        nome = request.form.get("nome")
        cpf = request.form.get("cpf")
        telefone = request.form.get("telefone")
        email = request.form.get("email")
        curso = request.form.get("curso")

        try:
            conn = get_db_connection()
            cur = conn.cursor()
            cur.execute(
                """
                UPDATE usuarios
                SET nome = %s, cpf = %s, telefone = %s, curso = %s, email = %s
                WHERE id = %s;
            """,
                (nome, cpf, telefone, curso, email, user_id),
            )
            conn.commit()
            cur.close()
            conn.close()
            return jsonify(
                {"status": "success", "message": "Usuário atualizado com sucesso!"}
            )
        except Exception as e:
            return jsonify({"status": "error", "message": str(e)}), 500
    else:
        return render_template("login_e_cadastro.html")


@app.route("/check_item_emprestado", methods=["GET"])
def check_item_loan():
    """
    Verifica se um item está emprestado para um usuário específico.

    A resposta é um JSON com as seguintes chaves:
        - status: "success" se a verificação foi realizada com sucesso, "error" caso contrário
        - message: Uma mensagem de sucesso ou erro
        - is_loaned: True se o item está emprestado para o usuário, False caso contrário
    """
    if "user" in session:
        user_id = request.args.get("user_id")
        item_id = request.args.get("item_id")

        conn = get_db_connection()
        cur = conn.cursor()
        try:
            cur.execute(
                """
                SELECT EXISTS (
                    SELECT 1 FROM itens_historico 
                    WHERE usuario_id = %s AND item_id = %s AND data_devolucao IS NULL
                )
                """,
                (user_id, item_id),
            )
            emprestado = cur.fetchone()[0]
            return jsonify({"status": "success", "emprestado": emprestado})
        except Exception as e:
            return jsonify({"status": "error", "message": str(e)})
        finally:
            cur.close()
            conn.close()
    else:
        return render_template("login_e_cadastro.html")


@app.route("/get_item", methods=["GET"])
def get_item():
    """
    Retorna o nome do item com o ID especificado.

    A resposta é um JSON com as seguintes chaves:
        - nome: O nome do item
        - status: "success" se o item foi encontrado, "error" caso contrário
        - message: Uma mensagem de sucesso ou erro

    A resposta é cacheada por 0 segundos, sendo atualizada a cada requisição.
    """
    if "user" in session:
        item_id = request.args.get("item_id")

        conn = get_db_connection()
        cur = conn.cursor()

        try:
            cur.execute("SELECT nome FROM itens WHERE id = %s", (item_id,))
            item = cur.fetchone()

            if item:
                return jsonify({"nome": item[0]})
            else:
                return jsonify({"status": "error", "message": "Item não encontrado."})

        except Exception as e:
            return jsonify({"status": "error", "message": str(e)})
        finally:
            cur.close()
            conn.close()
    else:
        return render_template("login_e_cadastro.html")


@app.route("/get_users", methods=["GET"])
def get_users():
    """
    Retorna a lista de usuários com base na busca realizada.

    A resposta é um JSON com os seguintes campos:
        - id: O ID do usuário
        - nome: O nome do usuário
        - cpf: O CPF do usuário
        - telefone: O telefone do usuário
        - curso: O curso do usuário
        - email: O e-mail do usuário

    A resposta é cacheada por 0 segundos, sendo atualizada a cada requisição.
    """
    if "user" in session:
        search = request.args.get("search", "")

        conn = get_db_connection()
        cur = conn.cursor()

        try:
            query = sql.SQL(
                "SELECT * FROM usuarios WHERE nome ILIKE %s OR cpf ILIKE %s"
            )
            cur.execute(query, (f"%{search}%", f"%{search}%"))
            users = cur.fetchall()
            return jsonify(users)
        except Exception as e:
            return jsonify({"status": "error", "message": str(e)})
        finally:
            cur.close()
            conn.close()
    else:
        return render_template("login_e_cadastro.html")


@app.route("/get_items", methods=["GET"])
def get_items():
    """
    Retorna a lista de itens com base na busca realizada.

    A resposta é um JSON com os seguintes campos:
        - id: O ID do item
        - nome: O nome do item
        - quantidade: A quantidade do item no estoque
        - localizacao: A localização do item no estoque

    A resposta é cacheada por 0 segundos, sendo atualizada a cada requisição.
    """
    if "user" in session:
        search = request.args.get("search", "")

        conn = get_db_connection()
        cur = conn.cursor()

        try:
            query = sql.SQL("SELECT * FROM itens WHERE nome ILIKE %s")
            cur.execute(query, (f"%{search}%",))
            items = cur.fetchall()
            return jsonify(items)
        except Exception as e:
            return jsonify({"status": "error", "message": str(e)})
        finally:
            cur.close()
            conn.close()
    else:
        return render_template("login_e_cadastro.html")


@app.route("/borrow_item", methods=["POST"])
def borrow_item():
    """
    Função para realizar o empréstimo de um item.

    Esta função espera que seja passado o user_id, items_id e a quantidade de cada item
    e a data de devolução prevista.

    A resposta será um JSON com os seguintes campos:
        - status: O status da operação (success ou error)
        - message: A mensagem de erro ou sucesso

    A resposta é cacheada por 0 segundos, sendo atualizada a cada requisição.
    """
    if "user" in session:
        user_id = request.form["user_id"]
        items_id = request.form["items_id"].split(",")
        items_id = [int(item) for item in items_id]
        tamanho = len(items_id)
        DevolucaoPrevista = request.form["DevolucaoPrevista"]
        conn = get_db_connection()
        cur = conn.cursor()

        try:
            i = 0
            while i < (len(items_id)):
                item_id = items_id[i]
                quantity_requested = items_id[i + 1]
                i += 2

                cur.execute(
                    "SELECT emprestar_item(%s, %s, %s, %s)",
                    (user_id, item_id, quantity_requested, DevolucaoPrevista),
                )

            conn.commit()

            if (tamanho) == 2:
                return jsonify(
                    {"status": "success", "message": "Item emprestado com sucesso"}
                )
            else:
                return jsonify(
                    {"status": "success", "message": "Itens emprestado com sucesso"}
                )
        except Exception as e:
            conn.rollback()
            print(f"Erro: {str(e)}")
            return jsonify({"status": "error", "message": str(e)})
        finally:
            cur.close()
            conn.close()
    else:
        return render_template("login_e_cadastro.html")


@app.route("/return_item", methods=["POST"])
def return_item():
    """
    Processa a devolução de um item emprestado.

    A requisição deve conter o ID do empréstimo a ser devolvido. A função atualiza
    a data de devolução no histórico de itens e incrementa a quantidade do item
    de volta ao estoque.

    A resposta é um JSON com as seguintes chaves:
        - status: "success" se a devolução foi processada com sucesso, "error" caso contrário
        - message: Uma mensagem de sucesso ou erro

    Se o usuário não estiver na sessão, redireciona para a página de login.

    A resposta é cacheada por 0 segundos, sendo atualizada a cada requisição.
    """
    if "user" in session:
        emprestimo_id = request.form["emprestimo_id"]

        conn = get_db_connection()
        cur = conn.cursor()

        try:
            cur.execute(
                "SELECT devolver_item(%s)",
                (emprestimo_id,),
            )

            conn.commit()
            return jsonify(
                {"status": "success", "message": "Item devolvido com sucesso"}
            )
        except Exception as e:
            conn.rollback()
            return jsonify({"status": "error", "message": str(e)})
        finally:
            cur.close()
            conn.close()
    else:
        return render_template("login_e_cadastro.html")


@app.route("/edit_item", methods=["POST"])
def edit_item():
    """
    Processa a edição de um item.

    A requisição deve conter os seguintes campos:
        - item_id: O ID do item a ser editado
        - item_name: O novo nome do item
        - item_quantity: A nova quantidade do item
        - item_location: A nova localização do item

    A resposta é um JSON com as seguintes chaves:
        - status: "success" se a edição foi processada com sucesso, "error" caso contrário
        - message: Uma mensagem de sucesso ou erro

    Se o usuário não estiver na sessão, redireciona para a página de login.

    A resposta é cacheada por 0 segundos, sendo atualizada a cada requisição.
    """
    if "user" in session:
        item_id = request.form["item_id"]
        item_name = request.form["item_name"]
        item_quantity = request.form["item_quantity"]
        item_location = request.form["item_location"]

        conn = get_db_connection()
        cur = conn.cursor()

        try:
            cur.execute("SELECT * FROM itens WHERE id = %s", (item_id,))
            if not cur.fetchone():
                return jsonify({"status": "error", "message": "Item não encontrado."})

            cur.execute(
                "UPDATE itens SET nome = %s, estoque = %s, localizacao = %s WHERE id = %s",
                (item_name, item_quantity, item_location, item_id),
            )
            conn.commit()
            return jsonify(
                {"status": "success", "message": "Item atualizado com sucesso!"}
            )
        except Exception as e:
            conn.rollback()
            return jsonify({"status": "error", "message": str(e)})
        finally:
            cur.close()
            conn.close()
    else:
        return render_template("login_e_cadastro.html")


@app.route("/delete_user", methods=["POST"])
def delete_user():
    """
    Deleta um usuário com base no seu ID.

    A resposta é um JSON com as seguintes chaves:
        - status: "success" se o usuário foi deletado com sucesso, "error" caso contrário
        - message: Uma mensagem de sucesso ou erro

    A resposta é cacheada por 0 segundos, sendo atualizada a cada requisição.
    """
    if "user" in session:
        user_id = request.form["user_id"]

        conn = get_db_connection()
        cur = conn.cursor()

        try:
            cur.execute("SELECT delete_user(%s)", (user_id,))

            conn.commit()
            return jsonify(
                {"status": "success", "message": "Usuário deletado com sucesso!"}
            )
        except Exception as e:
            conn.rollback()
            return jsonify({"status": "error", "message": str(e)})
        finally:
            cur.close()
            conn.close()
    else:
        return render_template("login_e_cadastro.html")


@app.route("/delete_item", methods=["POST"])
def delete_item():
    """
    Deleta um item do estoque com base no ID do item.

    A resposta é um JSON com as seguintes chaves:
        - status: "success" se o item foi deletado com sucesso, "error" caso contrário
        - message: Uma mensagem de sucesso ou erro

    A resposta é cacheada por 0 segundos, sendo atualizada a cada requisição.
    """

    if "user" in session:
        item_id = request.form["item_id"]

        conn = get_db_connection()
        cur = conn.cursor()

        try:

            cur.execute("SELECT delete_item(%s)", (item_id,))

            conn.commit()
            return jsonify(
                {"status": "success", "message": "Item excluído com sucesso!"}
            )
        except Exception as e:
            conn.rollback()
            return jsonify({"status": "error", "message": str(e)})
        finally:
            cur.close()
            conn.close()
    else:
        return render_template("login_e_cadastro.html")


@app.route("/get_estoque", methods=["GET"])
def get_estoque():
    """
    Retorna o estoque do item com base no ID do item.

    A resposta é um JSON com a quantidade do item em estoque.

    A resposta é cacheada por 0 segundos, portanto a quantidade do item em estoque é atualizada a cada requisição.
    """
    if "user" in session:
        item_id = request.args.get("item_id")

        conn = get_db_connection()
        cur = conn.cursor()

        try:
            cur.execute("SELECT estoque FROM itens WHERE id = %s", (item_id,))
            item_row = cur.fetchone()

            conn.commit()
            return jsonify(*item_row)
        except Exception as e:
            conn.rollback()
            print(f"Erro: {str(e)}")
            return jsonify({"status": "error", "message": str(e)})
        finally:
            cur.close()
            conn.close()
    else:
        return render_template("login_e_cadastro.html")


@app.route("/get_telefone_usuario", methods=["GET"])
def get_telefone_usuario():
    """
    Retorna o telefone do usuário com base no ID do emprestimo.

    A resposta é um JSON com o telefone do usuario.

    A resposta é cacheada por 0 segundos, portanto a telefone do usuario em estoque é atualizada a cada requisição.
    """
    if "user" in session:
        emprestimo_id = request.args.get("emprestimo_id")

        conn = get_db_connection()
        cur = conn.cursor()

        try:
            cur.execute(
                "SELECT telefone FROM usuarios WHERE id = (SELECT usuario_id FROM itens_historico WHERE id = %s)",
                (emprestimo_id,),
            )
            telefone = cur.fetchone()

            conn.commit()
            return jsonify(*telefone)
        except Exception as e:
            conn.rollback()
            print(f"Erro: {str(e)}")
            return jsonify({"status": "error", "message": str(e)})
        finally:
            cur.close()
            conn.close()
    else:
        return render_template("login_e_cadastro.html")


if __name__ == "__main__":
    app.run(debug=True, host="localhost", port=5000)
