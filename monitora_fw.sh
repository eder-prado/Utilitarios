#!/bin/bash
# monitora_fw.sh - Monitora processamento, memoria, conexoes e
# armazenamento de disco.
#
# Copyright (C) 2011 Thiago Milhomem <tmill15@msn.com>
#
# Este e' um software livre:
# Voce e' livre para altera-lo e redistribui-lo.
# NAO HA GARANTIAS, na maxima extensao permitida por lei.
#
# ------------------------------------------------------------
# Esse programa monitora e registra em log informacoes relati-
# vas a processamento, memoria, conexoes TCP e UDP e armazana-
# mento de disco.
#
# Uso: monitora_fw.sh [opcoes]
#
# Exemplo:
#
# Para monitorar firewall e logar em arquivo:
#
#	# monitora_fw.sh arquivo
#
# Para monitorar firewall utilizando informacoes do arquivo
# /proc/slabinfo (Opcao utilizada em firewall cluster):
#
#	# monitora_fw.sh arquivo slabinfo
#
# Opcoes: monitora_fw.sh [tela|ver|grafico|ajuda_grafico|arquivo] [slabinfo]
# ------------------------------------------------------------
#
# Versao atual: 0.16
# 	2011-03-25, Marcelo Mendonca <marcelo@m2.net.br>
#		- Exportacao da variavel de ambiente PATH
#		- Total de conexoes UDP
#		- TOP 15 de conexoes UDP
#		- Informacoes de cluster
#
# Licenca GPLv3+: GNU GPL versao 3 ou superior
#	<http://gnu.org/licences/gpl.html>
#

# Exporta variavel de ambiente PATH
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/samba/bin:/usr/local/samba/sbin:/usr/X11R6/bin:/aker/bin/common:/aker/bin/firewall:/aker/bin/asmg:/aker/bin/awg

# Configura o intervalo de atualizacao do script - modo arquivo e grafico
# Em segundos
tx_atualizacao='300'

# Variaveis globais
programa=$(basename "$0")
versao=`egrep "^# V.{10}l\b:" $0 | awk -F: '{ print $2 }' | tr -d ' '`
patch="2"
dir_logs="/var/log/monitora"
dir_backups="$dir_logs/backups"
rotatividade=+7

# Inicio

show_help(){
	echo "Uso: monitora_fw.sh (tela|ver|grafico|ajuda_grafico|arquivo) (slabinfo)"
}

# Verificacoes iniciais

if [ $USER != 'root' ];then
	echo "Execute o script como root.."
	exit 1
fi

if [ $# != 1 ];then
	if [ $# != 2 ];then
		show_help
		exit 1
	fi
fi

if [ ! -d "$dir_logs" ];then
	/bin/mkdir "$dir_logs"
fi

if [ ! -d "$dir_backups" ];then
	/bin/mkdir "$dir_backups"
fi
	

slabinfo=0
# Recebe argumento informado
tipo="$1"

if [ $# = 2 ];then
	if [ $1 = "arquivo" ];then
		if [ $2 = "slabinfo" ];then
			slabinfo=1
		else
			show_help
			exit 1
		fi	
	else
		show_help
		exit 1
	fi
fi		


backup(){

cat <<EOF> /tmp/monitor_backup.sh
#!/bin/bash
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/samba/bin:/usr/local/samba/sbin:/usr/X11R6/bin:/aker/bin/common:/aker/bin/firewall:/aker/bin/asmg:/aker/bin/awg
iniciar_backup="23:59:55"
while [ 1 ];do
hora=\`/bin/date | /bin/awk -F' ' '{ print \$4 }'\`
sleep 1
if [ \$hora = \$iniciar_backup ];then
  if [ -f "$dir_logs/monitora_fw.log" ];then
    /usr/bin/killall monitor_arquivo.sh 2> /dev/null
    monitora_backup=\`/bin/date +'monitora_fw-%Y-%m-%d.log'\`
    /bin/mv $dir_logs/monitora_fw.log $dir_backups/\$monitora_backup
    /usr/bin/find "$dir_backups" -name "monitora*" -mtime "$rotatividade" -exec /bin/rm -rf {} ';' 2> /dev/null
    /tmp/monitor_arquivo.sh  >> "$dir_logs"/monitora_fw.log &
    if [ -f "$dir_logs/slabinfo.log" ];then
      /usr/bin/killall monitor_slabinfo.sh 2> /dev/null
      slabinfo_backup=\`/bin/date +'slabinfo-%Y-%m-%d.log'\`
      /bin/mv $dir_logs/slabinfo.log $dir_backups/\$slabinfo_backup
      /usr/bin/find "$dir_backups" -name "slabinfo*" -mtime "$rotatividade" -exec /bin/rm -rf {} ';' 2> /dev/null
      /tmp/monitor_slabinfo.sh  >> "$dir_logs"/slabinfo.log &
    fi
    else
    exit 1
  fi
fi
done
EOF

}


screen(){

clear

while [ 1 ];do
proc_p1=`/bin/ps ax | grep fwhttppd | grep At | wc -l 2>> /dev/null`
proc_p2=`c=0; /bin/ps ax | grep fwhttppd | grep At |grep -v grep | cut -d"(" -f2 |cut -d")" -f1 | (while read i ; do c=$(expr $i + $c); done; echo $c;) 2>> /dev/null`
carga=`/bin/cat /proc/loadavg | cut -d " " -f1,2,3`
cpu=`/usr/bin/top -b -n1 | grep Cpu | cut -d:  -f2`
memoria=`/usr/bin/top -b -n1 | grep Mem | cut -d:  -f2`
swap=`/usr/bin/top -b -n1 | grep Swap| cut -d:  -f2`
data=`/bin/date`
disco=`/bin/df -h`

  echo "Status do firewall em: $data"
  echo
  echo "Processamento:"
  echo " $cpu"
  echo "Memoria:"
  echo "$memoria"
  echo "Swap:"
  echo " $swap"
  echo
  echo "---------------------------------------------------"
  echo "Carga do sistema: $carga"
  echo "Quantidade de processos fwhttppd: $[proc_p$patch]"
  echo
  echo "---------------------------------------------------"
  echo "Espaco em disco:"
  echo " $disco"
  echo
  echo
  echo
  sleep 8
  clear

done

}


archive(){


cat <<EOF> /tmp/monitor_arquivo.sh
#!/bin/bash
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/samba/bin:/usr/local/samba/sbin:/usr/X11R6/bin:/aker/bin/common:/aker/bin/firewall:/aker/bin/asmg:/aker/bin/awg
CT=1
while [ \$CT = 1 ];do

list_process_memory(){
export LC_ALL=C
>/tmp/top_mem_process.txt
/usr/bin/top -b -n1 |grep -A 1000 PID |sort -k 10 -n -r| head -15 >> /tmp/top_mem_process.txt
echo "  PID USER      PR  NI  VIRT  RES  SHR S %CPU %MEM    TIME+  COMMAND"
cat /tmp/top_mem_process.txt
}

verifica_cluster(){
/aker/bin/firewall/fwcluster mostra | egrep '^A.{1}l.{20}p' >> /dev/null
if [[ \$? -eq 1 ]];then
	/aker/bin/firewall/fwcluster mostra > /tmp/cluster_info.txt
	echo -n ' SIM'
	echo
	else
	echo -n ' NAO'
	echo
fi
}

carga=\`cat /proc/loadavg | cut -d " " -f1,2,3\`
cpu=\`/usr/bin/top -b -n1 | grep Cpu | cut -d:  -f2\`
memoria=\`/usr/bin/top -b -n1 | grep Mem | cut -d:  -f2\`
swap=\`/usr/bin/top -b -n1 | grep Swap| cut -d:  -f2\`
data=\`date\`
up_time=\`uptime | awk -F, '{ print \$1 }'\`
disco=\`/bin/df -h\`
tcp_con=\`/aker/bin/firewall/fwlist mostra tcp > /tmp/tcp_con.txt\`
list_tcp=\`grep -v Origem /tmp/tcp_con.txt | grep -v -| wc -l\`
top_tcp=\`grep -vi origem /tmp/tcp_con.txt | grep -v '\---' |cut -d: -f1 | sort -k1 | uniq -c | sort -nr -k1 | head -15\`
udp_con=\`/aker/bin/firewall/fwlist mostra udp > /tmp/udp_con.txt\`
list_udp=\`grep -v Origem /tmp/udp_con.txt | grep -v -| wc -l\`
top_udp=\`grep -vi origem /tmp/udp_con.txt | grep -v '\---' |cut -d: -f1 | sort -k1 | uniq -c | sort -nr -k1 | head -15\`
proc_p1=\`/bin/ps ax | grep fwhttppd | grep At | wc -l 2>> /dev/null\`
proc_p2=\`c=0; ps ax | grep fwhttppd | grep At |grep -v grep | cut -d"(" -f2 |cut -d")" -f1 | (while read i ; do c=\$(expr \$i + \$c); done; echo \$c;) 2>> /dev/null\`
#http_con=\`/bin/netstat -natp | grep fwhttppd > /tmp/http_con.txt\`
#top_http_a=\`awk '{ print \$4,\$5 }' /tmp/http_con.txt | egrep -v ':80\$' | grep ':80 ' | egrep -v '\.0:80 ' | awk '{ print \$2 }' | awk -F: '{ print \$1 }' | sort -k1 | uniq -c | sort -nr -k1 | head -15\`
#top_http_t=\`grep ':1000 ' /tmp/http_con.txt | egrep -v '\.0:1[0]{3}' | awk '{ print \$5 }' | awk -F: '{ print \$1 }' | sort -k1 | uniq -c | sort -nr -k1 | head -15\`
#top_https_t=\`grep ':984 ' /tmp/http_con.txt | egrep -v '\.0:984 ' | awk '{ print \$5 }' | awk -F: '{ print \$1 }' | sort -k1 | uniq -c | sort -nr -k1 | head -15\`


echo "Status do firewall em: \$data"
echo "UPTIME: \$up_time"
echo
echo "Processamento:"
echo " \$cpu"
echo "Memoria:"
echo "\$memoria"
echo "Swap:"
echo " \$swap"
echo
echo "---------------------------------------------------"
echo "Carga do sistema: \$carga"
echo
echo "---------------------------------------------------"
echo "Saida do meminfo:"
cat /proc/meminfo
echo
echo "---------------------------------------------------"
echo "Mapa de fragmentacao da memoria:"
cat /proc/buddyinfo
echo
echo "---------------------------------------------------"
echo "Total de conexoes TCP"
echo "\$list_tcp"
echo
echo "---------------------------------------------------"
echo "Top 15 conexoes TCP"
echo "\$top_tcp"
echo
echo
echo "---------------------------------------------------"
echo "Total de conexoes UDP"
echo "\$list_udp"
echo
echo "---------------------------------------------------"
echo "Top 15 conexoes UDP"
echo "\$top_udp"
echo
echo
echo "---------------------------------------------------"
echo "Quantidade de processos fwhttppd: \$proc_p$patch"
echo
echo "---------------------------------------------------"
echo "Top 15 conexoes HTTP (Proxy Ativo)"
#echo "\$top_http_a"
echo "Saida retirada por sobrecarga ao rodar netstat em firewalls com elevado processos fwhttppd em atendimento"
echo
echo
echo "---------------------------------------------------"
echo "Top 15 conexoes HTTP (Proxy Transparente)"
#echo "\$top_http_t"
echo "Saida retirada por sobrecarga ao rodar netstat em firewalls com elevado processos fwhttppd em atendimento"
echo
echo
echo "---------------------------------------------------"
echo "Top 15 conexoes HTTPS (Proxy Transparente)"
#echo "\$top_https_t"
echo "Saida retirada por sobrecarga ao rodar netstat em firewalls com elevado processos fwhttppd em atendimento"
echo
echo
echo "---------------------------------------------------"
echo "Informacoes de Cluster"
echo -n Licenca permite cluster:
verifica_cluster
echo
cat /tmp/cluster_info.txt 2>> /dev/null
echo
#egrep -A6 '^Aker F' /tmp/cluster_info.txt 2>> /dev/null
#echo
#egrep -A4 '^In.{10}a.{9}:' /tmp/cluster_info.txt 2>> /dev/null
#echo
#egrep -A9 '^Es.{11}d.{3}p.{6}:' /tmp/cluster_info.txt 2>> /dev/null
echo "---------------------------------------------------"
echo "Processos com mais uso de CPU:"
/usr/bin/top -b -n1 | grep -A15 PID
echo
echo "---------------------------------------------------"
echo "Processos com mais uso de memoria:"
list_process_memory
echo
echo "---------------------------------------------------"
echo "Espaco em disco:"
echo " \$disco"
echo
echo
echo
sleep $tx_atualizacao
done
EOF

if [ $slabinfo = 1 ];then

cat <<EOF> /tmp/monitor_slabinfo.sh
#!/bin/bash
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/samba/bin:/usr/local/samba/sbin:/usr/X11R6/bin:/aker/bin/common:/aker/bin/firewall:/aker/bin/asmg:/aker/bin/awg

delim="-----------------------------------------------------------------------------"

while [ 1 ];do
	data=\`date\`
	up_time=\`uptime | awk -F, '{ print \$1 }'\`
        echo "Saida do slabinfo em: \$data"
        echo "UPTIME: \$up_time" 
        echo
        cat /proc/slabinfo
        echo
        echo
        echo "Saida do slabinfo FILTRADA:"
        echo
        awk '{printf "%5d MB %s\n", \$3*\$4/(1024*1024), \$1}' < /proc/slabinfo | sort -n
        echo \$delim
        echo
        echo
        echo
        echo
	sleep $tx_atualizacao
done
EOF

fi

}

graph(){

cat <<EOF> /tmp/monitor_grafico.sh
#!/bin/bash
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/samba/bin:/usr/local/samba/sbin:/usr/X11R6/bin:/aker/bin/common:/aker/bin/firewall:/aker/bin/asmg:/aker/bin/awg
CT=1
while [ \$CT = 1 ];do

data=\`date '+%b %d %H:%M'\`
proc_p1=\`/bin/ps ax | grep fwhttppd | grep At | wc -l\`
proc_p2=\`c=0; ps ax | grep fwhttppd | grep At |grep -v grep | cut -d"(" -f2 |cut -d")" -f1 | (while read i ; do c=\$(expr \$i + \$c); done; echo \$c;)\`
load_5=\`cat /proc/loadavg | awk '{print \$1}'\`
load_10=\`cat /proc/loadavg | awk '{print \$2}'\`
load_15=\`cat /proc/loadavg | awk '{print \$3}'\`
cpu_us=\`/usr/bin/top -b -n1 | grep Cpu | awk '{print \$2}' | cut -d'%' -f1\`
cpu_sy=\`/usr/bin/top -b -n1 | grep Cpu | awk '{print \$4}' | cut -d'%' -f1\`
cpu_wa=\`/usr/bin/top -b -n1 | grep Cpu | awk '{print \$10}' | cut -d'%' -f1\`
mem_used=\`/usr/bin/top -b -n1 | grep Mem | awk '{print \$4}' | cut -dk -f1\`
mem_free=\`/usr/bin/top -b -n1 | grep Mem | awk '{print \$6}' | cut -dk -f1\`
mem_swap=\`/usr/bin/top -b -n1 | grep Swap | awk '{print \$4}' | cut -dk -f1\`
list_tcp=\`fwlist mostra tcp | grep -v Origem | grep -v -| wc -l\`
list_udp=\`fwlist mostra udp | grep -v Origem | grep -v -| wc -l\`
disk_var_log=\`/bin/df -h | grep var-log | awk '{print \$5}' | cut -d'%' -f1\`

echo "\$data,\$proc_p$patch,\$load_5,\$load_10,\$load_15,\$cpu_us,\$cpu_sy,\$cpu_wa,\$mem_used,\$mem_free,\$mem_swap,\$list_tcp,\$list_udp,\$disk_var_log"

sleep $tx_atualizacao
done
EOF

}

case $tipo in
		tela)
		  screen
		;;
		arquivo)
		  backup
		  chmod u+x /tmp/monitor_backup.sh
		  killall monitor_backup.sh 2> /dev/null
		  /tmp/monitor_backup.sh &
		  if [ $slabinfo != 1 ];then
		  	[ -f /tmp/monitor_arquivo.sh ] && rm /tmp/monitor_arquivo.sh
		  	archive
		  	chmod u+x /tmp/monitor_arquivo.sh
		  	killall monitor_arquivo.sh 2> /dev/null
		  	killall monitor_slabinfo.sh 2> /dev/null
		  	/tmp/monitor_arquivo.sh  >> "$dir_logs"/monitora_fw.log &
		  	echo "Processos criados como: monitor_arquivo.sh e monitor_backup.sh"
		  	echo "Arquivo de log em: $dir_logs/monitora_fw.log"
		  else
		  	[ -f /tmp/monitor_arquivo.sh ] && rm /tmp/monitor_arquivo.sh
		  	[ -f /tmp/monitor_slabinfo.sh ] && rm /tmp/monitor_slabinfo.sh
		  	archive
		  	chmod u+x /tmp/monitor_arquivo.sh
		  	chmod u+x /tmp/monitor_slabinfo.sh
		  	killall monitor_arquivo.sh 2> /dev/null
		  	killall monitor_slabinfo.sh 2> /dev/null
		  	/tmp/monitor_arquivo.sh  >> "$dir_logs"/monitora_fw.log &
		  	/tmp/monitor_slabinfo.sh  >> "$dir_logs"/slabinfo.log &
		  	echo "Processos criados como: monitor_slabinfo.sh, monitor_arquivo.sh e monitor_backup.sh"
		  	echo "Arquivo de log em: $dir_logs/monitora_fw.log"
		  	echo "Log do slabinfo em: $dir_logs/slabinfo.log"
		  fi
		;;
		grafico)
		  [ -f /tmp/monitor_grafico.sh ] && rm /tmp/monitor_grafico.sh
		  graph
		  chmod u+x /tmp/monitor_grafico.sh
		  killall monitor_grafico.sh 2> /dev/null
		  /tmp/monitor_grafico.sh >> "$dir_logs"/monitora_grafico.log &
		  echo "Processo criado como: monitor_grafico.sh"
		  echo "Arquivo de log em: $dir_logs/monitora_grafico.log"
		;;
		ver | -V | --version)
		  cat << EOF
GNU $programa $versao

Copyright (C) 2011 Free Software Foundation, Inc.
Licença GPLv3+: GNU GPL versão 3 ou superior <http://gnu.org/licenses/gpl.html>
Este é um software livre: você é livre para alterá-lo e redistribuí-lo.
NÃO HÁ GARANTIAS, na máxima extensão permitida por lei.
EOF
		;;
		ajuda_grafico)
		  echo "Ordem dos valores coletados (separados por virgula) para gerar os graficos:"
		  echo "  1.  Data"
		  echo "  2.  Processos HTTP"
		  echo "  3.  Carga do sistema - 5 minutos"
		  echo "  4.  Carga do sistema - 10 minutos"
		  echo "  5.  Carga do sistema - 15 minutos"
		  echo "  6.  CPU - us"
		  echo "  7.  CPU - sy"
		  echo "  8.  CPU - wa"
		  echo "  9.  Memoria usada"
		  echo "  10. Memoria livre"
		  echo "  11. Memoria swap usada"
		  echo "  12. Conexoes TCP"
		  echo "  13. Conexoes UDP"
		  echo "  14. Uso de disco - particao de log"
		;;
		*)
		  show_help
		;;
esac
