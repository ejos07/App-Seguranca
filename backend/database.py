import os
import polars as pl
from pymongo import MongoClient
from dotenv import load_dotenv

# Carrega as variáveis do ficheiro .env
load_dotenv()

# ==========================================
# LIGAÇÃO MONGODB
# ==========================================
def get_mongo_client():
    uri = os.getenv("MONGO_URI")
    try:
        return MongoClient(uri, tls=True, tlsInsecure=True)
    except Exception as e:
        print(f"Erro ao ligar ao MongoDB: {e}")
        return None

def consultar_senha_db(documento):
    client = get_mongo_client()
    if client:
        db = client["AppSeguranca"]
        usuario = db["credenciais"].find_one({"documento": documento})
        if usuario:
            return (usuario["senha"], usuario.get("alterada", 1))
    return None

def atualizar_senha(documento, nova_senha):
    client = get_mongo_client()
    if client:
        db = client["AppSeguranca"]
        db["credenciais"].update_one(
            {"documento": documento},
            {"$set": {"senha": nova_senha, "alterada": 1}},
            upsert=True
        )

# ==========================================
# CARREGAR UTILIZADORES (POLARS)
# ==========================================
def carregar_usuarios():
    caminhos = [
        r"B:\Parquet\Gente_gestao\csv\Base_local_funcionarios\rzt_func_workplace.csv",
        r"B:\Parquet\Gente_gestao\csv\Base_local_funcionarios\bv_func_workplace.csv",
        r"B:\Parquet\Gente_gestao\csv\Base_local_funcionarios\mb_func_workplace.csv"
    ]
    
    dfs = []
    for caminho in caminhos:
        if os.path.exists(caminho):
            try:
                df = pl.read_csv(caminho, separator=";", encoding="latin1", ignore_errors=True, infer_schema_length=10000)
                if "Nome" not in df.columns:
                    df = pl.read_csv(caminho, separator=",", encoding="utf8", ignore_errors=True, infer_schema_length=10000)
                
                df = df.with_columns([pl.col(c).cast(pl.Utf8) for c in df.columns])
                dfs.append(df)
            except Exception as e:
                print(f"Aviso ao ler {caminho}: {e}")

    if dfs:
        df_total = pl.concat(dfs, how="diagonal")
        df_total = df_total.filter(
            pl.col("Status").str.to_uppercase().is_in(["ATIVO", "EM FÉRIAS"])
        ).with_columns(
            pl.col("Documento").str.replace(r"\.0$", "").str.replace_all(r"\D", "").alias("Senha_Atual (Documento)")
        ).with_columns(
            pl.when(pl.col("Cargo").str.to_lowercase().str.contains("segurança"))
              .then(pl.lit("tecnico"))
              .otherwise(pl.lit("colaborador"))
              .alias("Perfil_App")
        ).select(["Nome", "Documento", "Status", "Cargo", "Senha_Atual (Documento)", "Perfil_App"])
    else:
        df_total = pl.DataFrame(schema={"Nome": pl.Utf8, "Documento": pl.Utf8, "Status": pl.Utf8, "Cargo": pl.Utf8, "Senha_Atual (Documento)": pl.Utf8, "Perfil_App": pl.Utf8})

    # UTILIZADOR MASTER INJETADO
    df_master = pl.DataFrame({
        "Nome": ["José Mario (Admin Master)"],
        "Documento": ["45923613859"], 
        "Status": ["Ativo"],
        "Cargo": ["ADMIN MASTER"], 
        "Senha_Atual (Documento)": ["45923613859"], 
        "Perfil_App": ["admin"]
    })
    
    return pl.concat([df_total, df_master], how="diagonal")


from pymongo import ReturnDocument

# ==========================================
# FUNÇÕES DE RELATOS
# ==========================================
def get_next_id(seq_name):
    client = get_mongo_client()
    if client:
        db = client["AppSeguranca"]
        ret = db["counters"].find_one_and_update(
            {"_id": seq_name},
            {"$inc": {"seq": 1}},
            upsert=True,
            return_document=ReturnDocument.AFTER
        )
        return ret["seq"]
    return 1

def inserir_relato_db(dados_dict):
    client = get_mongo_client()
    if client:
        db = client["AppSeguranca"]
        novo_id = get_next_id("relatos_id")
        
        dados_dict["id"] = novo_id
        dados_dict["ativo"] = 1
        
        db["relatos"].insert_one(dados_dict)
        return novo_id
    return None

def consultar_relatos_db():
    client = get_mongo_client()
    if client:
        db = client["AppSeguranca"]
        cursor = db["relatos"].find({"ativo": 1}).sort("id", -1)
        lista_relatos = list(cursor)
        for item in lista_relatos:
            if "_id" in item:
                item["_id"] = str(item["_id"]) # Converte o ObjectId do Mongo para string
        return lista_relatos
    return []