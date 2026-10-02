from pydantic import BaseModel
from typing import List

# ==========================================
# MODELOS DE LOGIN
# ==========================================
class LoginRequest(BaseModel):
    cpf: str
    senha: str

class NovaSenhaRequest(BaseModel):
    cpf: str
    nova_senha: str

# ==========================================
# MODELOS DE RELATOS
# ==========================================
class RelatoCreate(BaseModel):
    unb: str
    departamento: str
    relator: str
    relatado: str
    data_relato: str
    area_relatada: str
    processo: List[str]
    tarefa_atividade: str
    classificacao: str
    detalhe_classificacao: str
    acao_imediata: str
    descricao: str