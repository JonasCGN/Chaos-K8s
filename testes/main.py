import glob
import os
import pandas as pd
from collections import defaultdict
import matplotlib.pyplot as plt
import matplotlib
import numpy as np

matplotlib.use('tkAgg')

def obter_arquivos_statistics(base_dir):
    pattern = f"{base_dir}/**/statistics.csv"
    return glob.glob(pattern, recursive=True)  

def _to_float(value) -> float:
    try:
        return float(str(value))
    except ValueError:
        return 0.1
    
arquivos = obter_arquivos_statistics('simulation')
por_data_hora = defaultdict(list)

for arquivo in arquivos:
    partes = arquivo.split(os.sep)
    if len(partes) >= 5:
        data = f"{partes[1]}/{partes[2]}/{partes[3]}"  # YYYY/MM/DD
        hora = partes[4]  # HHMMSS
        chave = f"{data} {hora}"
        por_data_hora[chave].append(arquivo)
        


resultados = []

for chave, lista in por_data_hora.items():
    data, hora = chave.split()
    if len(lista) >= 1:
        for arq in lista:
            df = pd.read_csv(arq)
            nome_simulacao = os.path.basename(os.path.dirname(arq))
            metricas = dict(zip(df.iloc[:,0], df.iloc[:,1]))
            if "duration_hours" in metricas and "total_downtime" in metricas:
                duracao = metricas["duration_hours"]
                downtime = metricas["total_downtime"]
                disponibilidade = (1 - (_to_float(downtime) / _to_float(duracao))) * 100
                mean_recovery_time = metricas.get("mean_recovery_time", None)
                resultados.append({
                    "Simulação": nome_simulacao,
                    "Data": data,
                    "Hora": hora,
                    "Duração (h)": duracao,
                    "Downtime (h)": downtime,
                    "Disponibilidade (%)": disponibilidade,
                    "Mean Recovery Time": mean_recovery_time
                })
        if resultados:
            df_resultados = pd.DataFrame(resultados)

            # Gráfico de disponibilidade por simulação
            plt.figure()
            plt.plot(df_resultados["Simulação"].str.extract(r'(\d+)')[0].astype(int), df_resultados["Disponibilidade (%)"], marker='o')
            plt.xticks(df_resultados["Simulação"].str.extract(r'(\d+)')[0].astype(int)) 
            plt.title("Disponibilidade por Simulação")
            plt.xlabel("Iteração")
            plt.ylabel("Disponibilidade (%)")
            # Define o limite inferior do eixo y como o mínimo arredondado para baixo (sempre pra menos)
            plt.ylim(np.floor(df_resultados["Disponibilidade (%)"].min()*100)/100, 100) 
            plt.xticks(rotation=45)
            plt.tight_layout()
            # plt.savefig("disponibilidade_por_simulacao.png")
            # plt.show()

            # Gráfico de mean_recovery_time por simulação
            plt.figure()
            plt.plot(df_resultados["Simulação"], df_resultados["Mean Recovery Time"], marker='o', color='orange')
            plt.title("Mean Recovery Time por Simulação")
            plt.xlabel("Iteração")
            plt.ylabel("Mean Recovery Time (s)")
            plt.xticks(rotation=45)
            plt.tight_layout()
            # plt.savefig("mean_recovery_time_por_simulacao.png")
            # plt.show()

            print(df_resultados.to_string(index=False))
            resultados = []
            

arquivos = obter_arquivos_statistics('simulation')
por_data_hora = defaultdict(list)

for arquivo in arquivos:
    partes = arquivo.split(os.sep)
    if len(partes) >= 5:
        data = f"{partes[1]}/{partes[2]}/{partes[3]}"  # YYYY/MM/DD
        hora = partes[4]  # HHMMSS
        chave = f"{data} {hora}"
        por_data_hora[chave].append(arquivo)

resultados = []
all_results = []

for chave, lista in por_data_hora.items():
    data, hora = chave.split()
    if len(lista) >= 1:
        for arq in lista:
            df = pd.read_csv(arq)
            nome_simulacao = os.path.basename(os.path.dirname(arq))
            metricas = dict(zip(df.iloc[:,0], df.iloc[:,1]))
            if "duration_hours" in metricas and "total_downtime" in metricas:
                duracao = metricas["duration_hours"]
                downtime = metricas["total_downtime"]
                disponibilidade = (1 - (_to_float(downtime) / _to_float(duracao))) * 100
                mean_recovery_time = metricas.get("mean_recovery_time", None)
                resultados.append({
                    "Simulação": nome_simulacao,
                    "Data": data,
                    "Hora": hora,
                    "Duração (h)": duracao,
                    "Downtime (h)": downtime,
                    "Disponibilidade (%)": disponibilidade,
                    "Mean Recovery Time": mean_recovery_time
                })
                
        if resultados:
            index = 0
            df_resultados = pd.DataFrame(resultados)

            # print(df_resultados.to_string(index=False))
            all_results.append(resultados)
            
            index += 1
            resultados = []
            
# Combine all mean recovery times into a single DataFrame for display
tabelas = []
for res in all_results:
    df_resultados = pd.DataFrame(res)
    mean_recovery = df_resultados['Mean Recovery Time'].mean()
    std_recovery = df_resultados['Mean Recovery Time'].std()
    mean_disponibilidade = df_resultados['Disponibilidade (%)'].mean()
    std_disponibilidade = df_resultados['Disponibilidade (%)'].std()
    mean_downtime = df_resultados['Downtime (h)'].mean()
    std_downtime = df_resultados['Downtime (h)'].std()
    tabelas.append({
        "Data": df_resultados["Data"].iloc[0],
        "Hora": df_resultados["Hora"].iloc[0],
        "N_Iteracoes": len(df_resultados),
        "Mean Recovery Time (média ±σ )": f"{mean_recovery:.2f} (±{std_recovery:.2f})",
        "Dispobinilidade (Média)": f"{mean_disponibilidade:.2f} (±{std_disponibilidade:.2f})",
        "Downtime (h) (Média)": f"{mean_downtime:.2f} (±{std_downtime:.2f})"
    })

def salvar_csv_resumido(df_resultados, data, hora):
    # Garante formato: ano/mes/dia/hora/experiment_iterations.csv
    ano, mes, dia = data.split('/')
    n_iter = len(df_resultados)
    pasta = f"{ano}/{mes}/{dia}/{hora}"
    os.makedirs(pasta, exist_ok=True)
    caminho_csv = os.path.join(pasta, f"experiment_{n_iter}.csv")
    # Monta o DataFrame no formato pedido
    df_csv = pd.DataFrame({
        "iteration": range(1, n_iter+1),
        "duration_hours": df_resultados["Duração (h)"].astype(float),
        "total_available_time": df_resultados["Duração (h)"].astype(float) - df_resultados["Downtime (h)"].astype(float),
        "availability_percentage": df_resultados["Disponibilidade (%)"].astype(float),
        "total_failures": [int(sim.split('_')[-1]) if '_' in sim else 0 for sim in df_resultados["Simulação"]],
        "timestamp": [f"{data.replace('/','-')}T{df_resultados['Hora'].iloc[i]}" for i in range(n_iter)]
    })
    df_csv.to_csv(caminho_csv, index=False)
    print(f"CSV salvo em: {caminho_csv}")

# Exemplo de uso ao final do seu script:
for res in all_results:
    df_resultados = pd.DataFrame(res)
    if not df_resultados.empty:
        data = df_resultados["Data"].iloc[0]
        hora = df_resultados["Hora"].iloc[0]
        salvar_csv_resumido(df_resultados, data, hora)

tabela_final = pd.DataFrame(tabelas)

# === GERAÇÃO DE CSV RESUMIDO NO FORMATO SOLICITADO ===
def salvar_csv_resumido_legivel(df_resultados, data, hora):
    # Garante formato: ano/mes/dia/hora/experiment_iterations.csv
    ano, mes, dia = data.split('/')
    pasta = f"{ano}/{mes}/{dia}/{hora}"
    os.makedirs(pasta, exist_ok=True)
    n_iter = len(df_resultados)
    caminho_csv = os.path.join(pasta, f"experiment_{n_iter}.csv")
    # Monta o DataFrame no formato pedido
    df_csv = pd.DataFrame({
        "Simulação": [f"ITERACAO{i+1}" for i in range(n_iter)],
        "Data": [data]*n_iter,
        "Hora": [hora]*n_iter,
        "Duração (h)": df_resultados["Duração (h)"].astype(float),
        "Downtime (h)": df_resultados["Downtime (h)"].astype(float),
        "Disponibilidade (%)": df_resultados["Disponibilidade (%)"].astype(float),
        "Mean Recovery Time": df_resultados["Mean Recovery Time"].astype(float)
    })
    df_csv.to_csv(caminho_csv, index=False)
    print(f"CSV salvo em: {caminho_csv}\n{df_csv}")

# Gera o CSV para cada conjunto de resultados
for res in all_results:
    df_resultados = pd.DataFrame(res)
    if not df_resultados.empty:
        data = df_resultados["Data"].iloc[0]
        hora = df_resultados["Hora"].iloc[0]
        salvar_csv_resumido_legivel(df_resultados, data, hora)
# === FIM DO BLOCO DE GERAÇÃO DE CSV ===