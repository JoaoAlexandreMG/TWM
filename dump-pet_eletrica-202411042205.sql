--
-- PostgreSQL database dump
--

-- Dumped from database version 16.3
-- Dumped by pg_dump version 16.3

-- Started on 2024-11-04 22:05:49

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

DROP DATABASE pet_eletrica;
--
-- TOC entry 4851 (class 1262 OID 16958)
-- Name: pet_eletrica; Type: DATABASE; Schema: -; Owner: postgres
--

CREATE DATABASE pet_eletrica WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'Portuguese_Brazil.1252';


ALTER DATABASE pet_eletrica OWNER TO postgres;

\connect pet_eletrica

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 4 (class 2615 OID 2200)
-- Name: public; Type: SCHEMA; Schema: -; Owner: pg_database_owner
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO pg_database_owner;

--
-- TOC entry 4852 (class 0 OID 0)
-- Dependencies: 4
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: pg_database_owner
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- TOC entry 228 (class 1255 OID 17569)
-- Name: add_item(character, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.add_item(p_nome character, p_localizacao integer, p_estoque integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO itens (nome, localizacao, estoque)
    VALUES (p_nome, p_localizacao, p_estoque);
END;
$$;


ALTER FUNCTION public.add_item(p_nome character, p_localizacao integer, p_estoque integer) OWNER TO postgres;

--
-- TOC entry 227 (class 1255 OID 17567)
-- Name: add_user(character varying, character varying, character varying, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.add_user(p_cpf character varying, p_nome character varying, p_telefone character varying, p_email text, p_curso text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF verificar_cpf_existente(p_cpf) THEN
        return 0;
    ELSE
        INSERT INTO usuarios (cpf, nome, telefone, curso, email)
        VALUES (p_cpf, p_nome, p_telefone, p_curso, p_email);
		return 1;
    END IF;
END;
$$;


ALTER FUNCTION public.add_user(p_cpf character varying, p_nome character varying, p_telefone character varying, p_email text, p_curso text) OWNER TO postgres;

--
-- TOC entry 242 (class 1255 OID 17584)
-- Name: delete_item(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.delete_item(item_id_to_delete integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Verifica se o item existe antes de deletar
    IF EXISTS (SELECT 1 FROM itens WHERE id = item_id_to_delete) THEN
        -- Deleta registros do histórico relacionados ao item
        DELETE FROM itens_historico WHERE item_id = item_id_to_delete;
        -- Deleta o item
        DELETE FROM itens WHERE id = item_id_to_delete;
        -- Retorna 1 para indicar sucesso
        RETURN 1;
    ELSE
        -- Retorna 0 para indicar que o item não foi encontrado
        RETURN 0;
    END IF;
END;
$$;


ALTER FUNCTION public.delete_item(item_id_to_delete integer) OWNER TO postgres;

--
-- TOC entry 243 (class 1255 OID 17585)
-- Name: delete_user(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.delete_user(user_id_to_delete integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Verifica se o usuário existe antes de deletar
    IF EXISTS (SELECT 1 FROM usuarios WHERE id = user_id_to_delete) THEN
        -- Deleta os registros de empréstimo do usuário no histórico
        DELETE FROM itens_historico WHERE usuario_id = user_id_to_delete;
        -- Deleta o usuário
        DELETE FROM usuarios WHERE id = user_id_to_delete;
        -- Retorna 1 para indicar sucesso
        RETURN 1;
    ELSE
        -- Retorna 0 para indicar que o usuário não foi encontrado
        RETURN 0;
    END IF;
END;
$$;


ALTER FUNCTION public.delete_user(user_id_to_delete integer) OWNER TO postgres;

--
-- TOC entry 241 (class 1255 OID 17581)
-- Name: devolver_item(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.devolver_item(id_emprestimo integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    item_id_emprestimo integer;
    item_qntd_emprestimo integer;
BEGIN
    -- Atualizar a data de devolução do item no histórico
    UPDATE itens_historico 
    SET data_devolucao = CURRENT_DATE 
    WHERE id = id_emprestimo;

    -- Obter o ID do item e a quantidade emprestada
    SELECT itens_historico.item_id, itens_historico.qntd 
    INTO item_id_emprestimo, item_qntd_emprestimo
    FROM itens_historico
    WHERE itens_historico.id = id_emprestimo;

    -- Atualizar o estoque do item com a quantidade devolvida
    UPDATE itens 
    SET estoque = estoque + item_qntd_emprestimo 
    WHERE id = item_id_emprestimo;
END;
$$;


ALTER FUNCTION public.devolver_item(id_emprestimo integer) OWNER TO postgres;

--
-- TOC entry 240 (class 1255 OID 17578)
-- Name: emprestar_item(integer, integer, integer, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.emprestar_item(p_usuario_id integer, p_item_id integer, p_qntd integer, p_data_prevista_devolucao date) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    estoque_var integer;
BEGIN
    -- Obter o estoque atual do item
    SELECT INTO estoque_var estoque FROM itens WHERE id = p_item_id;

    -- Verificar se há estoque suficiente
    IF estoque_var >= p_qntd THEN
            -- Atualizar o estoque do item
            UPDATE itens 
            SET estoque = estoque - p_qntd 
            WHERE id = p_item_id;

            -- Inserir o novo registro de empréstimo
            INSERT INTO itens_historico (usuario_id, item_id, qntd, data_emprestimo, data_devolucao, data_prevista_devolucao)
            VALUES (p_usuario_id, p_item_id, p_qntd, CURRENT_DATE, NULL, p_data_prevista_devolucao);

            -- Retornar sucesso
            RETURN 1;
    ELSE
        -- Erro: estoque insuficiente
        RAISE EXCEPTION 'Erro: estoque insuficiente para o item solicitado.';
    END IF;

    RETURN 0;
END;
$$;


ALTER FUNCTION public.emprestar_item(p_usuario_id integer, p_item_id integer, p_qntd integer, p_data_prevista_devolucao date) OWNER TO postgres;

--
-- TOC entry 226 (class 1255 OID 17564)
-- Name: verificar_cpf_existente(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.verificar_cpf_existente(p_cpf character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Retorna TRUE se o CPF existir, caso contrário retorna FALSE
    RETURN EXISTS (
        SELECT 1 FROM usuarios WHERE cpf = p_cpf
    );
END;
$$;


ALTER FUNCTION public.verificar_cpf_existente(p_cpf character varying) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 216 (class 1259 OID 17024)
-- Name: itens; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.itens (
    id integer NOT NULL,
    nome character varying(255) NOT NULL,
    localizacao integer,
    estoque integer NOT NULL
);


ALTER TABLE public.itens OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 17120)
-- Name: itens_historico; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.itens_historico (
    id integer NOT NULL,
    usuario_id integer NOT NULL,
    item_id integer NOT NULL,
    data_emprestimo timestamp without time zone NOT NULL,
    data_devolucao timestamp without time zone,
    data_prevista_devolucao timestamp without time zone,
    qntd integer
);


ALTER TABLE public.itens_historico OWNER TO postgres;

--
-- TOC entry 218 (class 1259 OID 17109)
-- Name: usuarios; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usuarios (
    id integer NOT NULL,
    cpf character varying(14) NOT NULL,
    nome character varying(100) NOT NULL,
    telefone character varying(15) NOT NULL,
    curso text DEFAULT 'Sem Curso'::text NOT NULL,
    email text
);


ALTER TABLE public.usuarios OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 17533)
-- Name: emprestimos_ativos; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.emprestimos_ativos AS
 SELECT ih.id,
    u.nome AS nome_usuario,
    i.nome AS nome_item,
    ih.qntd,
    ih.data_emprestimo,
    ih.data_prevista_devolucao
   FROM ((public.itens_historico ih
     JOIN public.usuarios u ON ((u.id = ih.usuario_id)))
     JOIN public.itens i ON ((i.id = ih.item_id)))
  WHERE (ih.data_devolucao IS NULL);


ALTER VIEW public.emprestimos_ativos OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 17548)
-- Name: emprestimos_atrasados; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.emprestimos_atrasados AS
 SELECT ih.id,
    u.nome AS nome_usuario,
    i.nome AS nome_item,
    ih.qntd,
    ih.data_emprestimo,
    ((CURRENT_DATE)::timestamp without time zone - ih.data_prevista_devolucao) AS dias_atraso
   FROM ((public.itens_historico ih
     JOIN public.usuarios u ON ((u.id = ih.usuario_id)))
     JOIN public.itens i ON ((i.id = ih.item_id)))
  WHERE ((ih.data_devolucao IS NULL) AND (ih.data_prevista_devolucao < CURRENT_DATE));


ALTER VIEW public.emprestimos_atrasados OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 17558)
-- Name: emprestimos_historico; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.emprestimos_historico AS
 SELECT ih.id,
    u.nome AS nome_usuario,
    i.nome AS nome_item,
    ih.qntd,
    ih.data_emprestimo,
    ih.data_devolucao
   FROM ((public.itens_historico ih
     JOIN public.usuarios u ON ((u.id = ih.usuario_id)))
     JOIN public.itens i ON ((i.id = ih.item_id)))
  WHERE (ih.data_devolucao IS NOT NULL);


ALTER VIEW public.emprestimos_historico OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 17119)
-- Name: itens_historico_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.itens_historico_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.itens_historico_id_seq OWNER TO postgres;

--
-- TOC entry 4853 (class 0 OID 0)
-- Dependencies: 219
-- Name: itens_historico_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.itens_historico_id_seq OWNED BY public.itens_historico.id;


--
-- TOC entry 215 (class 1259 OID 17023)
-- Name: itens_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.itens_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.itens_id_seq OWNER TO postgres;

--
-- TOC entry 4854 (class 0 OID 0)
-- Dependencies: 215
-- Name: itens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.itens_id_seq OWNED BY public.itens.id;


--
-- TOC entry 217 (class 1259 OID 17108)
-- Name: usuarios_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.usuarios_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.usuarios_id_seq OWNER TO postgres;

--
-- TOC entry 4855 (class 0 OID 0)
-- Dependencies: 217
-- Name: usuarios_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.usuarios_id_seq OWNED BY public.usuarios.id;


--
-- TOC entry 222 (class 1259 OID 17517)
-- Name: usuarios_painel; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usuarios_painel (
    id integer NOT NULL,
    nome character varying(100) NOT NULL,
    email character varying(100) NOT NULL,
    senha character varying(255) NOT NULL,
    data_cadastro timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.usuarios_painel OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 17516)
-- Name: usuarios_painel_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.usuarios_painel_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.usuarios_painel_id_seq OWNER TO postgres;

--
-- TOC entry 4856 (class 0 OID 0)
-- Dependencies: 221
-- Name: usuarios_painel_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.usuarios_painel_id_seq OWNED BY public.usuarios_painel.id;


--
-- TOC entry 4668 (class 2604 OID 17027)
-- Name: itens id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.itens ALTER COLUMN id SET DEFAULT nextval('public.itens_id_seq'::regclass);


--
-- TOC entry 4671 (class 2604 OID 17123)
-- Name: itens_historico id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.itens_historico ALTER COLUMN id SET DEFAULT nextval('public.itens_historico_id_seq'::regclass);


--
-- TOC entry 4669 (class 2604 OID 17112)
-- Name: usuarios id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios ALTER COLUMN id SET DEFAULT nextval('public.usuarios_id_seq'::regclass);


--
-- TOC entry 4672 (class 2604 OID 17520)
-- Name: usuarios_painel id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios_painel ALTER COLUMN id SET DEFAULT nextval('public.usuarios_painel_id_seq'::regclass);


--
-- TOC entry 4839 (class 0 OID 17024)
-- Dependencies: 216
-- Data for Name: itens; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.itens VALUES (2, 'Sugador de Solda (Fita Verde)', 1, 0);
INSERT INTO public.itens VALUES (3, 'Sugador de Solda (Azul)', 1, 1);
INSERT INTO public.itens VALUES (170, 'Garrafa Térmica', 5, 0);
INSERT INTO public.itens VALUES (199, 'Chassi robô seguidor de trilha', 5, 1);
INSERT INTO public.itens VALUES (192, 'Tinta Guache Vermelha 500 ml', 5, 1);
INSERT INTO public.itens VALUES (178, 'Cartazes Variados', 5, 100);
INSERT INTO public.itens VALUES (190, 'Tinta Guache Branca 500 ml', 5, 2);
INSERT INTO public.itens VALUES (165, 'Cabos desemcapados', 4, 100);
INSERT INTO public.itens VALUES (168, 'Copos de Vidro', 5, 5);
INSERT INTO public.itens VALUES (186, 'Refil de Vassoura', 5, 1);
INSERT INTO public.itens VALUES (229, 'Notebook Dell', 7, 0);
INSERT INTO public.itens VALUES (207, 'Baterias 9 V Lacradas', 5, 1);
INSERT INTO public.itens VALUES (162, 'Cabo ETHERNET', 4, 3);
INSERT INTO public.itens VALUES (187, 'Rodinha de Abdominal', 5, 1);
INSERT INTO public.itens VALUES (215, 'Caixa de Crachás', 5, 99);
INSERT INTO public.itens VALUES (4, 'Marreta de Borracha', 1, 1);
INSERT INTO public.itens VALUES (204, 'Interruptores', 5, 2);
INSERT INTO public.itens VALUES (174, 'Guardanapos', 5, 6);
INSERT INTO public.itens VALUES (213, 'Fonte para Base Carregadora (Fonte 9 V)', 5, 0);
INSERT INTO public.itens VALUES (171, 'Escumadeira', 5, 1);
INSERT INTO public.itens VALUES (177, 'Desinfetante', 5, 1);
INSERT INTO public.itens VALUES (241, 'Memórias DDR', 7, 0);
INSERT INTO public.itens VALUES (167, 'Caixa com componentes eletrônicos', 4, 3);
INSERT INTO public.itens VALUES (166, 'Parafusos, porcas e afins', 4, 100);
INSERT INTO public.itens VALUES (169, 'Jarra de Vidro', 5, 2);
INSERT INTO public.itens VALUES (172, 'Saco com copos descartáveis', 5, 1);
INSERT INTO public.itens VALUES (173, 'Talheres e Pratos descartáveis', 5, 100);
INSERT INTO public.itens VALUES (176, 'Esponjas', 5, 9);
INSERT INTO public.itens VALUES (179, 'Produtos de Limpeza', 5, 5);
INSERT INTO public.itens VALUES (182, 'Rolos de Papel Alumínio', 5, 3);
INSERT INTO public.itens VALUES (183, 'Vassoura', 5, 1);
INSERT INTO public.itens VALUES (184, 'Rodo', 5, 1);
INSERT INTO public.itens VALUES (185, 'Panos', 5, 5);
INSERT INTO public.itens VALUES (189, 'Tinta Guache Laranja 250 ml', 5, 2);
INSERT INTO public.itens VALUES (195, 'Corneta', 5, 1);
INSERT INTO public.itens VALUES (196, 'Rodas para robô seguidor de trilha', 5, 10);
INSERT INTO public.itens VALUES (202, 'Fios e Jumpers', 5, 1);
INSERT INTO public.itens VALUES (203, 'Placa para tomada', 5, 3);
INSERT INTO public.itens VALUES (206, 'Parafusos e Buchas', 5, 100);
INSERT INTO public.itens VALUES (208, 'Leitores Código de Barras', 5, 5);
INSERT INTO public.itens VALUES (209, 'Rádios Comunicadores', 5, 4);
INSERT INTO public.itens VALUES (210, 'WebCam', 5, 1);
INSERT INTO public.itens VALUES (211, 'Switch', 5, 1);
INSERT INTO public.itens VALUES (212, 'Base Carregadora', 5, 2);
INSERT INTO public.itens VALUES (217, 'Adaptadores Tomada T', 5, 2);
INSERT INTO public.itens VALUES (218, 'Adaptador VGA-DVI', 5, 1);
INSERT INTO public.itens VALUES (219, 'Caixa com Motores DC', 5, 100);
INSERT INTO public.itens VALUES (221, 'Mochilas', 5, 100);
INSERT INTO public.itens VALUES (5, 'Chave de Fenda (Verde/Grande)', 1, 1);
INSERT INTO public.itens VALUES (223, 'Tinta para impressora Epson 664', 7, 10);
INSERT INTO public.itens VALUES (224, 'Tinta para impressora Epson 664420', 7, 3);
INSERT INTO public.itens VALUES (225, 'Tinta para impressora Epson 664220', 7, 2);
INSERT INTO public.itens VALUES (226, 'Canetão azul', 7, 1);
INSERT INTO public.itens VALUES (227, 'HD Samsung', 7, 1);
INSERT INTO public.itens VALUES (228, 'SSD SATA 240Gb', 7, 1);
INSERT INTO public.itens VALUES (230, 'Cartucho para canetão', 7, 9);
INSERT INTO public.itens VALUES (231, 'Apagadores', 7, 2);
INSERT INTO public.itens VALUES (232, 'Canetão', 7, 7);
INSERT INTO public.itens VALUES (233, 'Teclado ABNT', 7, 5);
INSERT INTO public.itens VALUES (234, 'Cooler fan', 7, 5);
INSERT INTO public.itens VALUES (235, 'Canetas laser JEELB', 7, 5);
INSERT INTO public.itens VALUES (236, 'Bomba de ar', 7, 1);
INSERT INTO public.itens VALUES (238, 'Capacetes brancos', 7, 21);
INSERT INTO public.itens VALUES (239, 'Caixa com componentes para TUR', 7, 1);
INSERT INTO public.itens VALUES (242, 'Processador Intel Core Duo 05', 7, 2);
INSERT INTO public.itens VALUES (243, 'Processor Intel Core Duo 06', 7, 2);
INSERT INTO public.itens VALUES (244, 'Cabos SATA', 7, 5);
INSERT INTO public.itens VALUES (245, 'Cooler speed controller', 7, 1);
INSERT INTO public.itens VALUES (246, 'Bases para monitores', 7, 5);
INSERT INTO public.itens VALUES (247, 'Fonte', 7, 1);
INSERT INTO public.itens VALUES (248, 'Lâmpadas brancas 23 W', 7, 8);
INSERT INTO public.itens VALUES (249, 'Lâmpadas brancas 20W', 7, 3);
INSERT INTO public.itens VALUES (188, 'Tinta Guache Amarela 500 ml', 5, 1);
INSERT INTO public.itens VALUES (200, 'Carretel de linha', 5, 1);
INSERT INTO public.itens VALUES (181, 'Bolas (Carimpet e outras atividades)', 5, 0);
INSERT INTO public.itens VALUES (163, 'Circuitos Integrados', 4, 100);
INSERT INTO public.itens VALUES (240, 'Memórias DDR2', 7, 3);
INSERT INTO public.itens VALUES (180, 'Álcool 70%', 5, 1);
INSERT INTO public.itens VALUES (201, 'Transformadores', 5, 4);
INSERT INTO public.itens VALUES (214, 'Baterias 9 V', 5, 17);
INSERT INTO public.itens VALUES (191, 'Tinta Guache Verde 500 ml', 5, 1);
INSERT INTO public.itens VALUES (216, 'Adaptadores HDMI-VGA', 5, 1);
INSERT INTO public.itens VALUES (197, 'Dados', 5, 7);
INSERT INTO public.itens VALUES (205, 'Baterias para robô', 5, 2);
INSERT INTO public.itens VALUES (175, 'Sacos Plásticos', 5, 100);
INSERT INTO public.itens VALUES (164, 'Jmpers', 4, 100);
INSERT INTO public.itens VALUES (161, 'Cabo SATA', 4, 2);
INSERT INTO public.itens VALUES (194, 'Tinta Guache Azul 500 ml', 5, 1);
INSERT INTO public.itens VALUES (198, 'Boquilha lâmpada', 5, 4);
INSERT INTO public.itens VALUES (193, 'Tinta Guache Preta 250 ml', 5, 1);
INSERT INTO public.itens VALUES (220, 'Componentes para Robô Seguidor de Trilha', 5, 100);
INSERT INTO public.itens VALUES (250, 'Lâmpadas Incandecentes 100W', 7, 4);
INSERT INTO public.itens VALUES (251, 'Soquete de lâmpada', 7, 1);
INSERT INTO public.itens VALUES (253, 'Caixa com DVDs e CDs Variados', 7, 1);
INSERT INTO public.itens VALUES (254, 'Vela de LED', 7, 13);
INSERT INTO public.itens VALUES (255, 'Micro Retifica', 7, 1);
INSERT INTO public.itens VALUES (256, 'Caixas plásticas', 7, 8);
INSERT INTO public.itens VALUES (257, 'Rolo para pintura', 7, 1);
INSERT INTO public.itens VALUES (258, 'Lata de tinta para piso', 7, 2);
INSERT INTO public.itens VALUES (259, 'Lata de tinta para madeira e metal', 7, 2);
INSERT INTO public.itens VALUES (260, 'Tabuleiro de Xadrez (Tecido)', 7, 1);
INSERT INTO public.itens VALUES (261, 'Baterias de Carro 12MF45', 7, 2);
INSERT INTO public.itens VALUES (262, 'Baterias 12 V 7 A (Selada)', 7, 2);
INSERT INTO public.itens VALUES (263, 'Cadernos Pequenos de Anotação', 7, 3);
INSERT INTO public.itens VALUES (266, 'Estabilizadores 500 W', 7, 2);
INSERT INTO public.itens VALUES (267, 'Documentos PET', 7, 100);
INSERT INTO public.itens VALUES (268, 'Impressoras', 7, 4);
INSERT INTO public.itens VALUES (273, 'Cortinas', 7, 4);
INSERT INTO public.itens VALUES (274, 'Ferro de Solda 60 W', 7, 4);
INSERT INTO public.itens VALUES (8, 'Chave de Fenda (Amarela/Grande)', 1, 1);
INSERT INTO public.itens VALUES (9, 'Chave de Fenda (Amarela/Pequena)', 1, 1);
INSERT INTO public.itens VALUES (10, 'Chave de Fenda (Preta e Amarela/Média)', 1, 1);
INSERT INTO public.itens VALUES (11, 'Chave de Fenda (Preta e Amarela/Pequena)', 1, 1);
INSERT INTO public.itens VALUES (12, 'Chave de Fenda (Preta e Amarela/Grande)', 1, 1);
INSERT INTO public.itens VALUES (25, 'Alicate de Bico (Preto)', 1, 0);
INSERT INTO public.itens VALUES (13, 'Chave de Fenda (Preta/Grande)', 1, 2);
INSERT INTO public.itens VALUES (14, 'Lixas Finas', 1, 2);
INSERT INTO public.itens VALUES (15, 'Lixas Grossas', 1, 1);
INSERT INTO public.itens VALUES (17, 'Chave Philips (Preta e Vermelha/Média)', 1, 1);
INSERT INTO public.itens VALUES (34, 'Alicate de Corte (Laranja)', 1, 0);
INSERT INTO public.itens VALUES (18, 'Chave Philips (Preta e Vermelha/Pequena)', 1, 1);
INSERT INTO public.itens VALUES (19, 'Chave Philips (Amarela/Grande)', 1, 2);
INSERT INTO public.itens VALUES (20, 'Chave Philips (Amarela/Pequena)', 1, 1);
INSERT INTO public.itens VALUES (21, 'Chave Philips (Laranja/Pequena)', 1, 0);
INSERT INTO public.itens VALUES (22, 'Alicate Universal (Amarelo e Preto/Grande)', 1, 1);
INSERT INTO public.itens VALUES (23, 'Alicate Universal (Amarelo e Azul/Médio)', 1, 1);
INSERT INTO public.itens VALUES (24, 'Alicate de Bico (Vermelho e Preto)', 1, 1);
INSERT INTO public.itens VALUES (26, 'Alicate de Bico (Azul)', 1, 1);
INSERT INTO public.itens VALUES (27, 'Alicate de Cabo Ethernet', 1, 1);
INSERT INTO public.itens VALUES (28, 'Alicate de Bico Curvo', 1, 1);
INSERT INTO public.itens VALUES (29, 'Alicate de Corte (Vermelho)', 1, 1);
INSERT INTO public.itens VALUES (30, 'Alicate de Corte (Vermelho e Preto)', 1, 2);
INSERT INTO public.itens VALUES (31, 'Alicate de Corte (Preto)', 1, 1);
INSERT INTO public.itens VALUES (32, 'Alicate de Corte (Preto e Vermelho/Grande)', 1, 1);
INSERT INTO public.itens VALUES (33, 'Alicate de Corte (Azul)', 1, 1);
INSERT INTO public.itens VALUES (35, 'Chave Inglesa', 1, 1);
INSERT INTO public.itens VALUES (36, 'Conectores RJ45', 1, 9);
INSERT INTO public.itens VALUES (37, 'Serra', 1, 1);
INSERT INTO public.itens VALUES (38, 'Lanterna', 1, 1);
INSERT INTO public.itens VALUES (39, 'WD40 500 ml', 1, 1);
INSERT INTO public.itens VALUES (40, 'WD40 300 ml', 1, 1);
INSERT INTO public.itens VALUES (41, 'Acetona', 1, 1);
INSERT INTO public.itens VALUES (42, 'Pasta para Soldar 450 g', 1, 1);
INSERT INTO public.itens VALUES (43, 'Pasta para Soldar 110 g', 1, 1);
INSERT INTO public.itens VALUES (44, 'Limpa Contato', 1, 1);
INSERT INTO public.itens VALUES (45, 'Álcool Isopropílico 99%', 1, 1);
INSERT INTO public.itens VALUES (46, 'Pasta Térmica', 1, 1);
INSERT INTO public.itens VALUES (48, 'Tesoura (Grande)', 1, 1);
INSERT INTO public.itens VALUES (49, 'Tesoura (Preta/Pequena)', 1, 3);
INSERT INTO public.itens VALUES (50, 'Tesoura (Verde/Pequena)', 1, 1);
INSERT INTO public.itens VALUES (51, 'Tesoura (Azul/Pequena)', 1, 1);
INSERT INTO public.itens VALUES (52, 'Cola Bastão', 1, 1);
INSERT INTO public.itens VALUES (53, 'Fita Zebrada', 1, 2);
INSERT INTO public.itens VALUES (54, 'Caixa com Grampos (1000 Unidades)', 1, 3);
INSERT INTO public.itens VALUES (55, 'Caixa com Grampos (5000 Unidades)', 1, 5);
INSERT INTO public.itens VALUES (56, 'Rolos de Etiqueta', 1, 9);
INSERT INTO public.itens VALUES (57, 'Fita Crepe', 1, 4);
INSERT INTO public.itens VALUES (58, 'Durex Grosso', 1, 9);
INSERT INTO public.itens VALUES (59, 'Durex Médio', 1, 1);
INSERT INTO public.itens VALUES (60, 'Durex Fino', 1, 2);
INSERT INTO public.itens VALUES (61, 'Tubo Cola Branca', 1, 1);
INSERT INTO public.itens VALUES (62, 'Estilete (Azul e Preto)', 1, 1);
INSERT INTO public.itens VALUES (63, 'Estilete (Azul Transparente)', 1, 1);
INSERT INTO public.itens VALUES (65, 'Estilete (Preto)', 1, 1);
INSERT INTO public.itens VALUES (66, 'Caixa Lâmina Estilete', 1, 1);
INSERT INTO public.itens VALUES (67, 'Tubo Cola Quente', 1, 14);
INSERT INTO public.itens VALUES (68, 'Régua', 1, 3);
INSERT INTO public.itens VALUES (69, 'Carimbo PET Elétrica', 1, 1);
INSERT INTO public.itens VALUES (70, 'Almofada de Carimbo', 1, 1);
INSERT INTO public.itens VALUES (71, 'Enforca Gato Preto (100 unidades)', 1, 1);
INSERT INTO public.itens VALUES (72, 'Taxinha', 1, 1);
INSERT INTO public.itens VALUES (73, 'Alfinetes (50 unidades)', 1, 1);
INSERT INTO public.itens VALUES (74, 'Protoboard', 1, 21);
INSERT INTO public.itens VALUES (75, 'Multímetro MINIPA ET-2507A', 1, 1);
INSERT INTO public.itens VALUES (76, 'Multímetro DT830B', 1, 1);
INSERT INTO public.itens VALUES (77, 'Multímetro MINIPA ET-1600', 1, 1);
INSERT INTO public.itens VALUES (79, 'Multímetro DT830D', 1, 6);
INSERT INTO public.itens VALUES (80, 'Percloreto de Ferro', 1, 4);
INSERT INTO public.itens VALUES (81, 'Placa de Fenolite', 1, 11);
INSERT INTO public.itens VALUES (82, 'Pistola de Cola Quente (Preto e Laranja)', 1, 1);
INSERT INTO public.itens VALUES (84, 'Fita Isolante', 1, 4);
INSERT INTO public.itens VALUES (85, 'Fita Dupla Face', 1, 2);
INSERT INTO public.itens VALUES (86, 'Balança de Precisão', 2, 1);
INSERT INTO public.itens VALUES (87, 'Placa MSP430', 2, 2);
INSERT INTO public.itens VALUES (88, 'Carregadores (caixa do telefone fixo)', 2, 3);
INSERT INTO public.itens VALUES (89, 'Fontes Variáveis', 2, 2);
INSERT INTO public.itens VALUES (90, 'Fonte Variável', 2, 1);
INSERT INTO public.itens VALUES (91, 'Furadeira', 2, 1);
INSERT INTO public.itens VALUES (92, 'Brocas Variadas (caixa da furadeira)', 2, 9);
INSERT INTO public.itens VALUES (93, 'Brocas Variadas (sacos na caixa de furadeira)', 2, 7);
INSERT INTO public.itens VALUES (94, 'Kit 3 Microfone com Fio', 2, 1);
INSERT INTO public.itens VALUES (95, 'Alicates da Caixa de Furadeira', 2, 2);
INSERT INTO public.itens VALUES (96, 'Chave Mandril de Furadeira', 2, 1);
INSERT INTO public.itens VALUES (97, 'Punho de Mango para Furadeira', 2, 1);
INSERT INTO public.itens VALUES (98, 'Chave Hexagonal (Chave T)', 2, 1);
INSERT INTO public.itens VALUES (99, 'Chaves Combinadas', 2, 6);
INSERT INTO public.itens VALUES (100, 'Kit Chaves Allen', 2, 8);
INSERT INTO public.itens VALUES (101, 'Chave de Bico', 2, 1);
INSERT INTO public.itens VALUES (83, 'Pistola de Cola Quente (Cinza)', 1, 1);
INSERT INTO public.itens VALUES (264, 'Placa de Rede LNIC-10/CS (PCI)', 7, 1);
INSERT INTO public.itens VALUES (269, 'Monitor AOC', 7, 1);
INSERT INTO public.itens VALUES (47, 'Kit Jogo Chave de Precisão', 1, 2);
INSERT INTO public.itens VALUES (252, 'Caixa com Flyers CEMIG', 7, 2);
INSERT INTO public.itens VALUES (272, 'Colchão inflável', 7, 0);
INSERT INTO public.itens VALUES (16, 'Kit Broca Furadeira', 1, 1);
INSERT INTO public.itens VALUES (7, 'Chave de Fenda (Amarela/Média)', 1, 2);
INSERT INTO public.itens VALUES (271, 'Livros Materiais Didáticos Bernoulli', 7, 22);
INSERT INTO public.itens VALUES (78, 'Multímetro UT58D', 1, 1);
INSERT INTO public.itens VALUES (265, 'Dicionário de Francês', 7, 1);
INSERT INTO public.itens VALUES (1, 'Sugador de Solda (Azul e Amarelo)', 1, 1);
INSERT INTO public.itens VALUES (102, 'Estilete (Verde e Preto)', 2, 2);
INSERT INTO public.itens VALUES (103, 'Lanterna (Preto)', 2, 2);
INSERT INTO public.itens VALUES (104, 'Lanterna (Azul)', 2, 1);
INSERT INTO public.itens VALUES (105, 'Lanterna (Vermelho)', 2, 1);
INSERT INTO public.itens VALUES (106, 'Lanterna (Preta e Azul)', 2, 1);
INSERT INTO public.itens VALUES (107, 'Estilete (Amarelo e Preto)', 2, 1);
INSERT INTO public.itens VALUES (108, 'Multímetro (Vermelho e Preto)', 2, 1);
INSERT INTO public.itens VALUES (109, 'Multímetro (Preto)', 2, 10);
INSERT INTO public.itens VALUES (110, 'Multímetro (Azul e Preto)', 2, 10);
INSERT INTO public.itens VALUES (111, 'Multímetro (Vermelho e Azul)', 2, 9);
INSERT INTO public.itens VALUES (112, 'Furadeira (Preta e Azul)', 2, 10);
INSERT INTO public.itens VALUES (113, 'Chave Philips (Azul)', 2, 14);
INSERT INTO public.itens VALUES (114, 'Chave Philips (Verde e Preto)', 2, 11);
INSERT INTO public.itens VALUES (115, 'Pistola de Cola Quente (Preto e Azul)', 2, 2);
INSERT INTO public.itens VALUES (116, 'Chave Phillips (Amarelo)', 2, 2);
INSERT INTO public.itens VALUES (117, 'Chave Phillips (Azul)', 2, 1);
INSERT INTO public.itens VALUES (118, 'Régua (Grande)', 2, 2);
INSERT INTO public.itens VALUES (119, 'Régua (Pequena)', 2, 1);
INSERT INTO public.itens VALUES (120, 'Fita de Medida (Preto e Amarelo)', 2, 2);
INSERT INTO public.itens VALUES (121, 'Fita de Medida (Preta)', 2, 7);
INSERT INTO public.itens VALUES (122, 'Fita de Medida (Vermelha)', 2, 1);
INSERT INTO public.itens VALUES (123, 'Fita de Medida (Azul)', 2, 1);
INSERT INTO public.itens VALUES (124, 'Brocas (Conjunto)', 2, 1);
INSERT INTO public.itens VALUES (125, 'Kit Chaves de Fenda', 2, 1);
INSERT INTO public.itens VALUES (126, 'Kit Chaves Philips', 2, 2);
INSERT INTO public.itens VALUES (127, 'Kit Chaves Combinadas', 2, 2);
INSERT INTO public.itens VALUES (128, 'Kit Chaves Allen (Pequeno)', 2, 4);
INSERT INTO public.itens VALUES (129, 'Kit Chaves Allen (Grande)', 2, 1);
INSERT INTO public.itens VALUES (130, 'Serra (Pequena)', 2, 1);
INSERT INTO public.itens VALUES (131, 'Serra (Grande)', 2, 6);
INSERT INTO public.itens VALUES (132, 'Serra (Média)', 2, 2);
INSERT INTO public.itens VALUES (133, 'Fita Adesiva (Pequena)', 2, 2);
INSERT INTO public.itens VALUES (134, 'Fita Adesiva (Grande)', 2, 2);
INSERT INTO public.itens VALUES (135, 'Cinta Isolante', 2, 4);
INSERT INTO public.itens VALUES (136, 'Cinta Adesiva', 2, 2);
INSERT INTO public.itens VALUES (137, 'Adaptador de Tomada', 2, 6);
INSERT INTO public.itens VALUES (138, 'Adaptador de Placa', 2, 1);
INSERT INTO public.itens VALUES (139, 'Conector de Áudio', 2, 1);
INSERT INTO public.itens VALUES (140, 'Carregador de Bateria', 3, 4);
INSERT INTO public.itens VALUES (141, 'Extensão de Tomada', 3, 2);
INSERT INTO public.itens VALUES (142, 'Lente de Aumento', 3, 1);
INSERT INTO public.itens VALUES (143, 'Ampola de Solda', 3, 1);
INSERT INTO public.itens VALUES (144, 'Calculadora Científica', 3, 2);
INSERT INTO public.itens VALUES (145, 'Técnico de Microfone', 3, 1);
INSERT INTO public.itens VALUES (146, 'Técnico de Placa', 3, 1);
INSERT INTO public.itens VALUES (148, 'Lupa de Mesa', 3, 1);
INSERT INTO public.itens VALUES (149, 'Alicate de Corte Frontal', 3, 0);
INSERT INTO public.itens VALUES (150, 'Alicate de Corte Lateral', 3, 3);
INSERT INTO public.itens VALUES (151, 'Chave de Teste', 3, 3);
INSERT INTO public.itens VALUES (152, 'Chave de Impacto', 3, 1);
INSERT INTO public.itens VALUES (153, 'Fita Adesiva (Preta)', 3, 1);
INSERT INTO public.itens VALUES (154, 'Fita Adesiva (Branca)', 3, 7);
INSERT INTO public.itens VALUES (155, 'Fita Adesiva (Cinza)', 3, 1);
INSERT INTO public.itens VALUES (156, 'Fita Adesiva (Vermelha)', 3, 2);
INSERT INTO public.itens VALUES (157, 'Fita Adesiva (Azul)', 4, 5);
INSERT INTO public.itens VALUES (158, 'Fita Adesiva (Amarela)', 4, 1);
INSERT INTO public.itens VALUES (159, 'Fita Adesiva (Laranja)', 4, 1);
INSERT INTO public.itens VALUES (160, 'Fita Adesiva (Rosa)', 4, 1);


--
-- TOC entry 4843 (class 0 OID 17120)
-- Dependencies: 220
-- Data for Name: itens_historico; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.itens_historico VALUES (144, 40, 215, '2024-10-28 00:00:00', NULL, '2024-11-01 00:00:00', 1);


--
-- TOC entry 4841 (class 0 OID 17109)
-- Dependencies: 218
-- Data for Name: usuarios; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.usuarios VALUES (40, '15525290707', 'João Alexandre', '34984347174', 'Engenharia Da Computação', 'j.sa@ufu.br');


--
-- TOC entry 4845 (class 0 OID 17517)
-- Dependencies: 222
-- Data for Name: usuarios_painel; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.usuarios_painel VALUES (8, 'João Alexandre A. De Sá', 'j.sa@ufu.br', 'a9fe79b7745ec81743ab464e4438b5428d72c6a7b5163d0d1cba9460cf6b4dd4', '2024-10-28 11:39:33.127111');


--
-- TOC entry 4857 (class 0 OID 0)
-- Dependencies: 219
-- Name: itens_historico_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.itens_historico_id_seq', 144, true);


--
-- TOC entry 4858 (class 0 OID 0)
-- Dependencies: 215
-- Name: itens_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.itens_id_seq', 284, true);


--
-- TOC entry 4859 (class 0 OID 0)
-- Dependencies: 217
-- Name: usuarios_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.usuarios_id_seq', 40, true);


--
-- TOC entry 4860 (class 0 OID 0)
-- Dependencies: 221
-- Name: usuarios_painel_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.usuarios_painel_id_seq', 8, true);


--
-- TOC entry 4685 (class 2606 OID 17125)
-- Name: itens_historico itens_historico_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.itens_historico
    ADD CONSTRAINT itens_historico_pkey PRIMARY KEY (id);


--
-- TOC entry 4675 (class 2606 OID 17029)
-- Name: itens itens_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.itens
    ADD CONSTRAINT itens_pkey PRIMARY KEY (id);


--
-- TOC entry 4677 (class 2606 OID 17100)
-- Name: itens unique_nome; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.itens
    ADD CONSTRAINT unique_nome UNIQUE (nome);


--
-- TOC entry 4679 (class 2606 OID 17118)
-- Name: usuarios usuarios_cpf_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_cpf_key UNIQUE (cpf);


--
-- TOC entry 4687 (class 2606 OID 17525)
-- Name: usuarios_painel usuarios_painel_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios_painel
    ADD CONSTRAINT usuarios_painel_email_key UNIQUE (email);


--
-- TOC entry 4689 (class 2606 OID 17523)
-- Name: usuarios_painel usuarios_painel_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios_painel
    ADD CONSTRAINT usuarios_painel_pkey PRIMARY KEY (id);


--
-- TOC entry 4681 (class 2606 OID 17116)
-- Name: usuarios usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_pkey PRIMARY KEY (id);


--
-- TOC entry 4682 (class 1259 OID 17416)
-- Name: idx_itens_historico_item_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_itens_historico_item_id ON public.itens_historico USING btree (item_id);


--
-- TOC entry 4683 (class 1259 OID 17415)
-- Name: idx_itens_historico_usuario_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_itens_historico_usuario_id ON public.itens_historico USING btree (usuario_id);


--
-- TOC entry 4690 (class 2606 OID 17131)
-- Name: itens_historico itens_historico_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.itens_historico
    ADD CONSTRAINT itens_historico_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.itens(id);


--
-- TOC entry 4691 (class 2606 OID 17126)
-- Name: itens_historico itens_historico_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.itens_historico
    ADD CONSTRAINT itens_historico_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id);


-- Completed on 2024-11-04 22:05:50

--
-- PostgreSQL database dump complete
--

