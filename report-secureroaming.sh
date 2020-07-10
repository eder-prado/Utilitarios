#!/bin/bash


# Cria relatorio de conexao Secure Roaming
# Uso: report-secureroaming.sh <qnt de dias 0 a 30 >
# 
# ----------------------------------------

# --------------------------------------------------
# Autor: Eder Ferreira - <eder.ferreira@ogasec.com>
# Criacao: 20/04/2020
# --------------------------------------------------

# Recebe intervalo em dias da pesquisa
Dias="$1"
[[ "$Dias" -gt '30' || -z $Dias ]] && echo "Periodo invalido - USE: $0 <dias> [entre 1 e 30]" && exit 1
#Periodo="$(date -d ""$Dias" day ago" +%d/%m/%Y) $(date +%d/%m/%Y)"

echo "Coletando dados aguarde..."

rm /tmp/ReportSR_day.txt 2> /dev/null
rm /tmp/ReportSR.txt 2> /dev/null
rm /tmp/relatorio.txt 2> /dev/null
for Dia in $(seq 0 $Dias) 
do
	echo "coletando dados dia: $(date -d ""$Dia" day ago" +%d/%m/%Y)"
	Periodo="$(date -d ""$Dia" day ago" +%d/%m/%Y) $(date -d ""$Dia" day ago" +%d/%m/%Y)"
	fwlog mostra eventos local $Periodo |grep 'Informacao do Secure Roaming' -A 1 >> /tmp/ReportSR_day.txt
	sleep 5
done
	egrep -i 'Sess.*o terminada\)|Roaming \(Seguran' -A 1 /tmp/ReportSR_day.txt|grep -v '^\-\-' >> /tmp/ReportSR.txt

# Coleta lista de sockets
IndiceSocket=($(egrep '[^?]\ \-\-\ [0-9]{1,3}\..*\:[0-9]{1,5}\ \-.\ ' /tmp/ReportSR.txt|awk -F '-- ' '{print $2}'|cut -d ' ' -f 1))

echo 'Usuario/Perfil,DataInicio,DataTermino,Duracao,IP Internet,IP Atribuido' > /tmp/relatorio.txt

echo "Dados coletados..."
echo "Iniciando geracao do relatorio..."
for Socket in ${IndiceSocket[@]}
do
	[[ $(grep -c $Socket /tmp/ReportSR.txt) != '2' ]] && continue
		Evento=($(grep $Socket /tmp/ReportSR.txt -B 1 | tr -d '-' |sed ':a;$!N;s/\n/|/;ta;'|sed 's/[ ]\+/\,/g'|sed 's/[|]\+/\|/g'))
		Usuario=$(echo $Evento|cut -d '|' -f 4|rev|cut -d ',' -f 2-|rev |cut -d ',' -f 2)
		DataInicio=$(echo $Evento|cut -d '|' -f 3|cut -d ',' -f 1,2|tr ',' ' ')
		DataFim=$(echo $Evento|cut -d ',' -f 1,2|tr ',' ' ')
		Duracao=$(echo $Evento|cut -d '|' -f 2|rev|cut -d ',' -f 1|rev); [[ ${#Duracao} -lt '8' ]] && Duracao="00:$Duracao"
		Socket="$Socket"
		IpClient=$(echo $Evento|cut -d '|' -f 2|rev|cut -d ',' -f 2|rev)

	echo "$Usuario,$DataInicio,$DataFim,$Duracao,$Socket,$IpClient" >> /tmp/relatorio.txt
done
	mv /tmp/relatorio.txt "/tmp/RelatorioSecureRoaming_$(date -d ""$Dias" day ago" +%d-%m-%Y)_$(date "+%d-%m-%Y").csv"
	echo "Relatorio gerado em: /tmp/RelatorioSecureRoaming_$(date -d ""$Dias" day ago" +%d-%m-%Y)_$(date "+%d-%m-%Y").csv"





