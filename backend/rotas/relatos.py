from fastapi import APIRouter, HTTPException
from models import RelatoCreate
from database import inserir_relato_db, consultar_relatos_db
from datetime import datetime

# Criamos o "mini-aplicativo" de rotas exclusivo para os relatos
router = APIRouter(prefix="/api/relatos", tags=["Relatos"])

@router.post("/")
def criar_relato(relato: RelatoCreate):
    # Converte o objeto do Pydantic para um dicionário nativo do Python
    dados = relato.model_dump()
    
    # Adiciona a data de cadastro do sistema
    dados["data_cadastro"] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    
    # Salva no banco
    id_gerado = inserir_relato_db(dados)
    
    if not id_gerado:
        raise HTTPException(status_code=500, detail="Erro ao salvar no banco de dados.")
        
    return {
        "status": "sucesso",
        "mensagem": "Relato registrado com sucesso!",
        "protocolo": f"REL-{int(id_gerado):06d}"
    }

@router.get("/")
def listar_relatos():
    # Busca os relatos ativos no banco de dados
    relatos = consultar_relatos_db()
    return {"status": "sucesso", "dados": relatos}