from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from pymongo import MongoClient, ReturnDocument
from datetime import datetime
import polars as pl
import os
import re
import certifi
from typing import List, Optional, Dict
import unicodedata
import pandas as pd

app = FastAPI()

@app.get("/")
def read_root():
    return {"message": "API de Segurança está rodando corretamente!"}

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_credentials=True,
    allow_methods=["*"], 
    allow_headers=["*"], 
)

MONGO_URI = "mongodb+srv://josemariofbg1101_db_user:OZQjw09OwDJQnl7L@seguranca-db.8daonoq.mongodb.net/?appName=seguranca-db"

def iniciar_conexao_mongo():
    try:
        return MongoClient(MONGO_URI, tls=True, tlsCAFile=certifi.where())
    except Exception as e:
        print(f"Erro ao conectar no MongoDB: {e}")
        return None

_usuarios_cache = []

def carregar_usuarios_rh():
    global _usuarios_cache
    if _usuarios_cache:
        return _usuarios_cache

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
                pass

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
        ).select(
            ["Nome", "Senha_Atual (Documento)", "Perfil_App", "Cargo", "Status"]
        )
    else:
        df_total = pl.DataFrame(schema={"Nome": pl.Utf8, "Senha_Atual (Documento)": pl.Utf8, "Perfil_App": pl.Utf8, "Cargo": pl.Utf8, "Status": pl.Utf8})

    df_total = df_total.filter(pl.col("Senha_Atual (Documento)") != "45923613859")

    df_master = pl.DataFrame({
        "Nome": ["José Mario (Admin Master)"],
        "Senha_Atual (Documento)": ["45923613859"], 
        "Perfil_App": ["admin"],
        "Cargo": ["ADMIN MASTER"], 
        "Status": ["Ativo"]
    })
    
    df_final = pl.concat([df_total, df_master], how="diagonal")
    _usuarios_cache = df_final.to_dicts()
    return _usuarios_cache

# =================================================================
# MODELOS PYDANTIC (Gerais e DTO)
# =================================================================
class LoginRequest(BaseModel):
    cpf: str
    senha: str

class AtualizarSenhaRequest(BaseModel):
    cpf: str
    nova_senha: str

class ResetSenhaRequest(BaseModel):
    cpf: str

class RelatoCreate(BaseModel):
    unb: str
    departamento: str
    relator: str
    relatado: str
    data_relato: str
    area_relatada: str
    processo: List[str]
    tarefa_atividade: str
    classificacao: Optional[str] = None
    detalhe_classificacao: str
    acao_imediata: str
    descricao: str

class DTOCreate(BaseModel):
    unb: str
    relator: str
    relatado: str
    data_relato: str
    tipo_dto: str
    tipo_comportamento: str
    respostas_dict: Dict[str, str]
    descricao: str
    acao_tomada: str

# =================================================================
# ROTAS EXISTENTES
# =================================================================
@app.post("/api/login")
def login(req: LoginRequest):
    cpf_limpo = re.sub(r'\D', '', req.cpf)
    usuarios = carregar_usuarios_rh()
    usuario_info = next((u for u in usuarios if u["Senha_Atual (Documento)"] == cpf_limpo), None)
    
    if not usuario_info: raise HTTPException(status_code=401, detail="Usuário não encontrado.")

    client = iniciar_conexao_mongo()
    db = client["AppSeguranca"]
    credencial = db["credenciais"].find_one({"documento": cpf_limpo})

    if not credencial:
        if req.senha == cpf_limpo: return {"status": "precisa_trocar_senha"}
        else: raise HTTPException(status_code=401, detail="Primeiro acesso: Use o seu CPF como senha inicial.")
    else:
        if req.senha == credencial["senha"]:
            return {
                "status": "sucesso",
                "usuario": {
                    "nome": usuario_info["Nome"],
                    "documento": cpf_limpo,
                    "perfil": usuario_info["Perfil_App"].lower(),
                    "cargo": usuario_info["Cargo"].upper()
                }
            }
        else: raise HTTPException(status_code=401, detail="Senha incorreta.")

@app.post("/api/atualizar_senha")
def atualizar_senha(req: AtualizarSenhaRequest):
    cpf_limpo = re.sub(r'\D', '', req.cpf)
    usuarios = carregar_usuarios_rh()
    usuario_info = next((u for u in usuarios if u["Senha_Atual (Documento)"] == cpf_limpo), None)
    if not usuario_info: raise HTTPException(status_code=404, detail="Usuário não encontrado.")

    client = iniciar_conexao_mongo()
    db = client["AppSeguranca"]
    db["credenciais"].update_one({"documento": cpf_limpo}, {"$set": {"senha": req.nova_senha, "alterada": 1}}, upsert=True)
    return {"status": "sucesso", "usuario": {"nome": usuario_info["Nome"], "perfil": usuario_info["Perfil_App"].lower()}}

@app.get("/api/usuarios/")
def listar_usuarios():
    return {"status": "sucesso", "dados": carregar_usuarios_rh()}

@app.post("/api/usuarios/resetar_senha")
def api_resetar_senha(req: ResetSenhaRequest):
    client = iniciar_conexao_mongo()
    client["AppSeguranca"]["credenciais"].delete_one({"documento": req.cpf})
    return {"status": "sucesso"}

def get_next_id(seq_name):
    client = iniciar_conexao_mongo()
    db = client["AppSeguranca"]
    ret = db["counters"].find_one_and_update(
        {"_id": seq_name},
        {"$inc": {"seq": 1}},
        upsert=True,
        return_document=ReturnDocument.AFTER
    )
    return ret["seq"]

@app.post("/api/relatos/")
def criar_relato(req: RelatoCreate):
    client = iniciar_conexao_mongo()
    db = client["AppSeguranca"]
    novo_id = get_next_id("relatos_id")
    
    doc = req.model_dump()
    doc["id"] = novo_id
    doc["data_cadastro"] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    doc["ativo"] = 1
    
    db["relatos"].insert_one(doc)
    protocolo = f"REL-{int(novo_id):06d}"
    return {"status": "sucesso", "protocolo": protocolo}

@app.get("/api/relatos/")
def listar_relatos():
    client = iniciar_conexao_mongo()
    db = client["AppSeguranca"]
    cursor = db["relatos"].find({"ativo": 1}).sort("id", -1)
    relatos = []
    for r in cursor:
        r["_id"] = str(r["_id"])
        r["protocolo"] = f"REL-{int(r['id']):06d}"
        relatos.append(r)
    return {"status": "sucesso", "dados": relatos}

# =================================================================
# FUNÇÕES DE SUPORTE E INTELIGÊNCIA DTO
# =================================================================
CAMINHO_MATRIZ_DTO = r"B:\Parquet\Seguranca_2026\codigo\MINASBEB\DTOs.xlsx"
CAMINHO_PLANILHA_FINAL = r"B:\Parquet\Seguranca_2026\csv\DTO\Planilha_Final_DTOs.xlsx"

def limpar_texto(texto: str) -> str:
    if not texto: return ""
    texto_sem_acento = unicodedata.normalize('NFD', str(texto))
    return texto_sem_acento.encode('ascii', 'ignore').decode('utf-8').upper().strip()

def super_limpar(texto: str) -> str:
    t = limpar_texto(texto)
    return re.sub(r'[^A-Z0-9]', '', t)

# =================================================================
# ROTAS DA API DE DTO
# =================================================================
@app.get("/api/dto/inteligencia")
def obter_inteligencia_dto():
    try:
        xls = pd.ExcelFile(CAMINHO_PLANILHA_FINAL)
        todas_abas = xls.sheet_names
        aba_matriz = todas_abas[0]
        abas_dtos = todas_abas[1:]
        
        whitelist_dinamica = [super_limpar(aba) for aba in abas_dtos]
        df_matriz = pl.read_excel(CAMINHO_PLANILHA_FINAL, sheet_name=aba_matriz)
        nome_col_dto = df_matriz.columns[0]
        colunas_q = [col for col in df_matriz.columns if col != nome_col_dto]
        
        dicionario_dinamico = {}
        for row in df_matriz.iter_rows(named=True):
            if not row[nome_col_dto]: continue
            tipo_dto_limpo = super_limpar(row[nome_col_dto])
            perguntas = [str(row[q]).strip() for q in colunas_q if row[q] and str(row[q]).strip() not in ["", "-", "nan", "None"]]
            if perguntas:
                dicionario_dinamico[tipo_dto_limpo] = perguntas
                
        df_cargos = pl.read_excel(CAMINHO_MATRIZ_DTO)
        cols = df_cargos.columns
        df_cargos = df_cargos.rename({cols[0]: "Cargo", cols[1]: "DTOs"}).fill_null("")
        df_cargos = df_cargos.with_columns(pl.col("DTOs").str.replace("Prev. Escorregão, tropeção e queda", "Prev. Escorregão tropeção e queda"))
        
        mapa_cargos = {}
        for row in df_cargos.iter_rows(named=True):
            cargo = limpar_texto(row["Cargo"])
            if row["DTOs"]:
                mapa_cargos[cargo] = [d.strip() for d in str(row["DTOs"]).split(", ")]
                
        return {
            "status": "sucesso", 
            "whitelist": whitelist_dinamica, 
            "perguntas": dicionario_dinamico, 
            "mapa_cargos": mapa_cargos
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/dto/equipe")
def obter_equipe(unb: str, lider: str, perfil: str):
    caminhos_unb = {
        "RIZATTI": r"B:\Parquet\Gente_gestao\csv\Base_local_funcionarios\rzt_func_workplace.csv", 
        "BEVALE": r"B:\Parquet\Gente_gestao\csv\Base_local_funcionarios\bv_func_workplace.csv", 
        "MINASBEB": r"B:\Parquet\Gente_gestao\csv\Base_local_funcionarios\mb_func_workplace.csv"
    }
    
    if unb not in caminhos_unb or not os.path.exists(caminhos_unb[unb]):
        return {"equipe": {}}
        
    try:
        caminho = caminhos_unb[unb]
        df = pl.read_csv(caminho, separator=";", ignore_errors=True, encoding="latin1", infer_schema_length=10000)
        if "NOME" not in [c.strip().upper() for c in df.columns]:
            df = pl.read_csv(caminho, separator=",", ignore_errors=True, encoding="utf8", infer_schema_length=10000)
            
        df = df.with_columns([pl.col(c).cast(pl.Utf8) for c in df.columns])
        df = df.rename({c: limpar_texto(c) for c in df.columns})
        
        if "STATUS" in df.columns:
            df = df.filter(pl.col("STATUS").str.strip_chars().str.to_uppercase().is_in(["ATIVO", "EM FÉRIAS", "EM FERIAS"]))
            
        if perfil != "admin":
            lider_limpo = limpar_texto(lider).replace("  ", " ") 
            if "NOME DO LIDER" in df.columns:
                df = df.filter(pl.col("NOME DO LIDER").str.replace_all(r"\s+", " ").str.strip_chars().str.to_uppercase() == lider_limpo)
                
        mapa = df.select(["NOME", "CARGO"]).drop_nulls().unique(subset=["NOME"])
        return {"equipe": dict(zip(mapa["NOME"].to_list(), mapa["CARGO"].to_list()))}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/dto/")
def criar_dto(req: DTOCreate):
    client = iniciar_conexao_mongo()
    db = client["AppSeguranca"]
    novo_id = get_next_id("dto_id")
    
    doc = req.model_dump()
    doc["id"] = novo_id
    doc["data_cadastro"] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    doc["ativo"] = 1
    
    db["dto_registros"].insert_one(doc)
    return {"status": "sucesso", "protocolo": f"DTO-{int(novo_id):06d}"}

@app.get("/api/dto/")
def listar_dtos():
    client = iniciar_conexao_mongo()
    db = client["AppSeguranca"]
    cursor = db["dto_registros"].find({"ativo": 1}).sort("id", -1)
    
    dtos = []
    for r in cursor:
        r["_id"] = str(r["_id"])
        r["protocolo"] = f"DTO-{int(r['id']):06d}"
        dtos.append(r)
    return {"status": "sucesso", "dados": dtos}


# =================================================================
# 🚀 MÓDULO GSD (DIÁLOGOS DE SEGURANÇA)
# =================================================================

class GSDCreate(BaseModel):
    unb: str
    departamento: str
    relator: str
    relatado: str
    data_relato: str
    horario_inicio: str
    horario_final: str
    respostas_dict: Dict[str, str]
    observacao: str

@app.get("/api/gsd/equipe")
def obter_equipe_gsd(unb: str, lider: str, isTST: str = "false"):
    caminhos_unb = {
        "RIZATTI": r"B:\Parquet\Gente_gestao\csv\Base_local_funcionarios\rzt_func_workplace.csv", 
        "BEVALE": r"B:\Parquet\Gente_gestao\csv\Base_local_funcionarios\bv_func_workplace.csv", 
        "MINASBEB": r"B:\Parquet\Gente_gestao\csv\Base_local_funcionarios\mb_func_workplace.csv"
    }
    
    if unb not in caminhos_unb or not os.path.exists(caminhos_unb[unb]):
        return {"funcionarios": []}
        
    try:
        caminho = caminhos_unb[unb]
        df = pl.read_csv(caminho, separator=";", ignore_errors=True, encoding="latin1", infer_schema_length=10000)
        if "NOME" not in [c.strip().upper() for c in df.columns]:
            df = pl.read_csv(caminho, separator=",", ignore_errors=True, encoding="utf8", infer_schema_length=10000)
            
        df = df.with_columns([pl.col(c).cast(pl.Utf8) for c in df.columns])
        df = df.rename({c: limpar_texto(c) for c in df.columns})
        
        if "STATUS" in df.columns:
            df = df.filter(pl.col("STATUS").str.strip_chars().str.to_uppercase().is_in(["ATIVO", "EM FÉRIAS", "EM FERIAS"]))
            
        # Regra de Segurança: TST vê todos, Supervisor vê apenas subordinados
        if isTST.lower() != "true":
            lider_limpo = limpar_texto(lider).replace("  ", " ") 
            if "NOME DO LIDER" in df.columns:
                df = df.filter(pl.col("NOME DO LIDER").str.replace_all(r"\s+", " ").str.strip_chars().str.to_uppercase() == lider_limpo)
                
        mapa = df.select(["NOME"]).drop_nulls().unique(subset=["NOME"]).sort("NOME")
        return {"funcionarios": mapa["NOME"].to_list()}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/gsd/")
def criar_gsd(req: GSDCreate):
    client = iniciar_conexao_mongo()
    db = client["AppSeguranca"]
    novo_id = get_next_id("gsd_id")
    
    doc = req.model_dump()
    doc["id"] = novo_id
    doc["data_cadastro"] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    doc["ativo"] = 1
    
    db["gsd_registros"].insert_one(doc)
    return {"status": "sucesso", "protocolo": f"GSD-{int(novo_id):06d}"}

@app.get("/api/gsd/")
def listar_gsds():
    client = iniciar_conexao_mongo()
    db = client["AppSeguranca"]
    cursor = db["gsd_registros"].find({"ativo": 1}).sort("id", -1)
    
    gsds = []
    for r in cursor:
        r["_id"] = str(r["_id"])
        r["protocolo"] = f"GSD-{int(r['id']):06d}"
        gsds.append(r)
    return {"status": "sucesso", "dados": gsds}

@app.delete("/api/gsd/{registro_id}")
def excluir_gsd(registro_id: str):
    client = iniciar_conexao_mongo()
    db = client["AppSeguranca"]
    
    # Suporta recebimento do ID como inteiro (ex: 15) ou como string completa (ex: GSD-000015)
    real_id = int(registro_id.replace("GSD-", "")) if registro_id.startswith("GSD-") else int(registro_id)
        
    resultado = db["gsd_registros"].update_one({"id": real_id}, {"$set": {"ativo": 0}})
    
    if resultado.modified_count == 1:
        return {"status": "sucesso", "mensagem": "Registro excluído logicamente."}
    else:
        raise HTTPException(status_code=404, detail="Registro não encontrado.")





# =================================================================
# 🚀 MÓDULO GSP (GUIA DE SEGURANÇA DE PUXADA)
# =================================================================

class GSPCreate(BaseModel):
    unb: str
    motorista: str
    placa_cavalo: str
    placa_carreta: str
    data_relato: str
    respostas_dict: Dict[str, str]
    observacao: str

@app.post("/api/gsp/")
def criar_gsp(req: GSPCreate):
    client = iniciar_conexao_mongo()
    db = client["AppSeguranca"]
    novo_id = get_next_id("gsp_id")
    
    doc = req.model_dump()
    doc["id"] = novo_id
    doc["data_cadastro"] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    doc["ativo"] = 1

    # Busca e salva o CPF do motorista para o relatório em Excel
    usuarios = carregar_usuarios_rh()
    motorista_info = next((u for u in usuarios if u["Nome"] == doc["motorista"]), None)
    doc["cpf_motorista"] = motorista_info["Senha_Atual (Documento)"] if motorista_info else "-"
    
    db["gsp_registros"].insert_one(doc)
    return {"status": "sucesso", "protocolo": f"GSP-{int(novo_id):06d}"}

@app.get("/api/gsp/")
def listar_gsp():
    client = iniciar_conexao_mongo()
    db = client["AppSeguranca"]
    cursor = db["gsp_registros"].find({"ativo": 1}).sort("id", -1)
    
    gsps = []
    for r in cursor:
        r["_id"] = str(r["_id"])
        r["protocolo"] = f"GSP-{int(r['id']):06d}"
        gsps.append(r)
    return {"status": "sucesso", "dados": gsps}

@app.delete("/api/gsp/{registro_id}")
def excluir_gsp(registro_id: str):
    client = iniciar_conexao_mongo()
    db = client["AppSeguranca"]
    
    real_id = int(registro_id.replace("GSP-", "")) if registro_id.startswith("GSP-") else int(registro_id)
        
    resultado = db["gsp_registros"].update_one({"id": real_id}, {"$set": {"ativo": 0}})
    
    if resultado.modified_count == 1:
        return {"status": "sucesso", "mensagem": "Registro excluído logicamente."}
    else:
        raise HTTPException(status_code=404, detail="Registro não encontrado.")