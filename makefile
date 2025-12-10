# 🔍 Descoberta automática do Control Plane IP via AWS CLI
CONTROL_PLANE_IP := $(shell aws ec2 describe-instances \
	--filters "Name=tag:Name,Values=ControlPlane" "Name=instance-state-name,Values=running" \
	--query 'Reservations[0].Instances[0].PublicIpAddress' \
	--output text 2>/dev/null || echo "AUTO_DISCOVERY_FAILED")

.PHONY: clear_maven run_deploy_aws run_deploy_aplication destroy_deploy_aplication \
	run_all_failures run_all_failures_aws run_graficos run_simulation \
	generate_config generate_config_aws generate_config_all generate_config_all_aws \
	check_aws_pods_tools setup_aws_pods_complete \
	build_enhanced_image install_tools_current_pods check_pods_tools \
	update_deployments_enhanced deploy_enhanced_setup ssh_cli_cp ssh_cli_wn install_debug_tools \
	get_control_plane_ip

# 🎯 Verifica e mostra o IP do Control Plane descoberto automaticamente
get_control_plane_ip:
	@echo "🔍 Descobrindo Control Plane IP via AWS CLI..."
	@if [ "$(CONTROL_PLANE_IP)" = "AUTO_DISCOVERY_FAILED" ] || [ "$(CONTROL_PLANE_IP)" = "None" ]; then \
		echo "❌ Erro: Não foi possível descobrir o IP do Control Plane automaticamente"; \
		echo "🔧 Verifique se:"; \
		echo "  - AWS CLI está configurado (aws configure)"; \
		echo "  - Instâncias têm tag Name contendo 'control'"; \
		echo "  - Instância está no estado 'running'"; \
		exit 1; \
	else \
		echo "✅ Control Plane IP descoberto: $(CONTROL_PLANE_IP)"; \
	fi

run_deploy_aws:
	cd targetsystem &&  cdk bootstrap --template my-bootstrap-template.yaml

run_deploy_aplication:
	cd targetsystem &&  cdk deploy --require-approval never

install_debug_tools:
	@echo "🛠️ Instalando deployments com debug-tools..."
	@$(MAKE) get_control_plane_ip
	@echo "📦 Aplicando configurações atualizadas..."
	cat /mnt/Jonas/Projetos/Artigos/1_Artigo/targetsystem/src/scripts/nodes/controlPlane/kubernetes/kub_deployment.yaml | ssh -i ~/.ssh/vockey.pem ubuntu@$(CONTROL_PLANE_IP) "sudo kubectl apply -f -"
	@echo ""
	@echo "🔄 Removendo pods antigos para forçar recriação com debug-tools..."
	ssh -i ~/.ssh/vockey.pem ubuntu@$(CONTROL_PLANE_IP) "sudo kubectl delete pods -l app=foo --force --grace-period=0"
	ssh -i ~/.ssh/vockey.pem ubuntu@$(CONTROL_PLANE_IP) "sudo kubectl delete pods -l app=bar --force --grace-period=0"
	ssh -i ~/.ssh/vockey.pem ubuntu@$(CONTROL_PLANE_IP) "sudo kubectl delete pods -l app=test --force --grace-period=0"
	@echo "⏳ Aguardando 45s para pods com debug-tools ficarem prontos..."
	sleep 45
	@echo ""
	@echo "✅ Verificando pods com debug-tools funcionando..."
	ssh -i ~/.ssh/vockey.pem ubuntu@$(CONTROL_PLANE_IP) 'sudo kubectl get pods | grep "2/2.*Running" || echo "Aguardando mais tempo..."'
	@echo ""
	@echo "🧪 Testando debug-tools nos pods disponíveis..."
	ssh -i ~/.ssh/vockey.pem ubuntu@$(CONTROL_PLANE_IP) ' \
		for pod in $$(sudo kubectl get pods | grep Running | grep bar-app | awk "{print \$$1}" | head -1); do \
			echo "=== Testando $$pod ==="; \
			sudo kubectl exec $$pod -c debug-tools -- ps aux | head -3 2>/dev/null && echo "✅ Debug-tools OK!" || echo "⚠️ Debug-tools não disponível"; \
		done \
	'
	@echo "✅ Debug-tools verificado!"

destroy_deploy_aplication:
	cd targetsystem &&  cdk destroy -f

clear_maven:
	cd targetsystem && mvn clean install

# 🎯 Executa TODOS os métodos de falha AWS com 5 iterações 
run_all_failures_aws:
	@echo ""
	@echo "📦 ===== TESTES DE PODS AWS ====="
# 	cd chaos_k8s && python3 reliability_tester.py --component pod --failure-method kill_processes --target bar-app-df9db64d6-bh55z --iterations 1 --interval 5 --aws
# 	@echo ""
# 	cd chaos_k8s && python3 reliability_tester.py --component pod --failure-method kill_init --target foo-app-86d576dd47-5w6s2 --iterations 1 --interval 5 --aws
# 	@echo ""
# 	@echo "🖥️  ===== TESTES DE WORKER NODES AWS ====="
# 	cd chaos_k8s && python3 reliability_tester.py --component worker_node --failure-method shutdown_worker_node --target ip-10-0-0-10 --iterations 1 --interval 10 --aws
# 	@echo ""
# 	cd chaos_k8s && python3 reliability_tester.py --component worker_node --failure-method kill_kubelet --target ip-10-0-0-10 --iterations 1 --interval 1 --aws
# 	@echo ""
# 	cd chaos_k8s && python3 reliability_tester.py --component worker_node --failure-method delete_kube_proxy --target ip-10-0-0-10 --iterations 1 --interval 10 --aws
# 	@echo ""
# 	cd chaos_k8s && python3 reliability_tester.py --component worker_node --failure-method restart_containerd --target ip-10-0-0-10  --iterations 1 --interval 10 --aws
# 	@echo ""
# 	@echo "🎛️  ===== TESTES DE CONTROL PLANE AWS ====="
# 	cd chaos_k8s && python3 reliability_tester.py --component control_plane --failure-method kill_control_plane_processes --target ip-10-0-0-219 --iterations 10 --interval 5 --aws
# 	@echo ""
	cd chaos_k8s && python3 reliability_tester.py --component control_plane --failure-method shutdown_control_plane --target ip-10-0-0-219 --iterations 1 --interval 5 --aws
	@echo ""
# 	cd chaos_k8s && python3 reliability_tester.py --component control_plane --failure-method kill_kube_apiserver --target ip-10-0-0-219 --iterations 1 --interval 5 --aws
# 	@echo ""
# 	cd chaos_k8s && python3 reliability_tester.py --component control_plane --failure-method kill_kube_controller_manager --target ip-10-0-0-219 --iterations 1 --interval 5 --aws
# 	@echo ""
# 	cd chaos_k8s && python3 reliability_tester.py --component control_plane --failure-method kill_kube_scheduler --target ip-10-0-0-219 --iterations 1 --interval 1 --aws
# 	@echo ""
# 	cd chaos_k8s && python3 reliability_tester.py --component control_plane --failure-method kill_etcd --target ip-10-0-0-219 --iterations 1 --interval 5 --aws --timeout extended
# 	@echo ""
# 	@echo "✅ Suite completa de testes AWS finalizada!"
# 	@echo "📁 Resultados salvos em: testes/2025/11/04/component/"

install_requirements:
	cd chaos_k8s && pip install -r requirements.txt

run_graficos:
	cd show_graficos && python3 graficos.py

run_simulation:
# 	source ~/venvs/py3env/bin/activate && 
	cd ./ && python3 -m chaos_k8s.cli.availability_cli --use-config-simples

run_simulation_aws:
# 	source ~/venvs/py3env/bin/activate && 
	cd ./ && python3 -m chaos_k8s.cli.availability_cli --use-config-simples --force-aws

generate_config:
# 	source ~/venvs/py3env/bin/activate && 
	cd ./ && python3 -m chaos_k8s.cli.availability_cli --get-config

generate_config_aws:
# 	source ~/venvs/py3env/bin/activate && 
	cd ./ && python3 -m chaos_k8s.cli.availability_cli --get-config --force-aws

generate_config_all:
# 	source ~/venvs/py3env/bin/activate && 
	cd ./ && python3 -m chaos_k8s.cli.availability_cli --get-config-all

generate_config_all_aws:
# 	source ~/venvs/py3env/bin/activate && 
	cd ./ && python3 -m chaos_k8s.cli.availability_cli --get-config-all --force-aws

ssh_cli_cp:
	@$(MAKE) get_control_plane_ip
	ssh -i ~/.ssh/vockey.pem ubuntu@$(CONTROL_PLANE_IP)

ssh_cli_wn:
	ssh -i ~/.ssh/vockey.pem ubuntu@13.220.170.35

# 🔍 VERIFICAR SE PODS AWS TÊM FERRAMENTAS (VIA SSH)
check_aws_pods_tools:
	@echo "🔍 Verificando ferramentas nos pods AWS (container debug-tools)..."
	@$(MAKE) get_control_plane_ip
	ssh -i ~/.ssh/vockey.pem ubuntu@$(CONTROL_PLANE_IP) ' \
		echo "✅ VERIFICAÇÃO DE FERRAMENTAS NO DEBUG-TOOLS"; \
		echo ""; \
		for pod in $$(sudo kubectl get pods -o name | grep -E "(foo-app|bar-app|test-app)" | cut -d/ -f2); do \
			echo "=== $$pod ==="; \
			if sudo kubectl exec $$pod -c debug-tools -- which ps >/dev/null 2>&1; then \
				echo "✅ debug-tools container: DISPONÍVEL"; \
				sudo kubectl exec $$pod -c debug-tools -- which ps >/dev/null 2>&1 && echo "  ✅ ps: OK" || echo "  ❌ ps: MISSING"; \
				sudo kubectl exec $$pod -c debug-tools -- which kill >/dev/null 2>&1 && echo "  ✅ kill: OK" || echo "  ❌ kill: MISSING"; \
				sudo kubectl exec $$pod -c debug-tools -- which pgrep >/dev/null 2>&1 && echo "  ✅ pgrep: OK" || echo "  ❌ pgrep: MISSING"; \
			else \
				echo "❌ debug-tools container: NÃO DISPONÍVEL"; \
				echo "  (Pod tem apenas container principal)"; \
			fi; \
			echo ""; \
		done; \
		echo "🎯 Verificação debug-tools concluída!" \
	'

# 🔄 WORKFLOW COMPLETO AWS: INSTALAR + VERIFICAR + TESTAR
setup_aws_pods_complete:
	make destroy_deploy_aplication
	make run_deploy_aws
	make run_deploy_aplication
	sleep 120
	@echo "🚀 Iniciando setup completo dos pods AWS..."
	@echo "1️⃣ Instalando ferramentas..."
	make install_debug_tools
# 	@echo "2️⃣ Verificando instalação..."
# 	make check_aws_pods_tools
	@echo "3️⃣ Testando comando kill..."
	ssh -i ~/.ssh/vockey.pem ubuntu@$(CONTROL_PLANE_IP) 'sudo kubectl exec $$(sudo kubectl get pods -o name | grep bar-app | cut -d/ -f2 | head -1) -- ps aux | head -2'
	@echo "✅ Setup AWS completo finalizado! Pods prontos para Kuber Bomber."

