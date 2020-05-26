#!/bin/bash
Regras=$(zcat /aker/config/firewall/regras-600.conf|tail -1|\
egrep -o '<source_ents>|<n_entity>[0-9]+|<set_size>[0-9]+|<dest_ents>|<n_entity>[0-9]+|<set_size>[0-9]+|<n_services>[0-9]+|<enabled>[0-1]')

echo $Regras|sed 's/source_ents/\nsource_ents/g'|egrep "^source_ents"|sed 's/>//g'|sed 's/<//g' > .regras.txt
Cont=1
Total=0
TotalEnable=0
TotalDisable=0
echo "Num|Status|Origem|Destino|Servico|Total"
cat .regras.txt|(while read RegraFiltragem
do
	Origem=$(echo "$RegraFiltragem"|egrep -o 'source_ents.*dest_ents')
	Destino=$(echo "$RegraFiltragem"|egrep -o 'dest_ents.*enabled')
	Servicos=$(echo "$RegraFiltragem"|egrep -o "n_services[0-9]+")
	Enable=$(echo "$RegraFiltragem"|egrep -o "enabled[0-1]"|sed 's/enabled//g') 
	[ $Enable -eq 1 ] && Status=Habilitado || Status=Desabilitado


		
	echo "$Origem"|egrep set_size > /dev/null
	if [ $? -eq '0' ]; then
		OrigemRegra=$(expr $(echo "$Origem"|egrep -o set_size.*|sed 's/n_entity[0-9]*//g' |sed 's/dest_ents//g'|sed 's/set_size//g'|sed 's/[ ]/\ \+\ /g'|sed 's/$/0/g'))
	else
		OrigemRegra=$(expr $(echo "$Origem"|egrep -o "n_entity[0-9]+"|sed 's/n_entity//g'))
	fi
	
	echo "$Destino"|egrep set_size > /dev/null
	if [ $? -eq '0' ]; then
		DestinoRegra=$(expr $(echo "$Destino"|egrep -o set_size.*|sed 's/set_size//g'|sed 's/dest_ents//'|sed 's/enabled//g'|sed 's/[ ]/\ \+\ /g'|sed 's/$/0/g'))
	else
		DestinoRegra=$(expr $(echo "$Destino"|egrep -o "n_entity[0-9]+"|sed 's/n_entity//g'))
	fi
	
		ServicosRegra=$(expr $(echo "$Servicos"|sed 's/n_services//g'))

		TotalRegra=$(expr $OrigemRegra \* $DestinoRegra \* $ServicosRegra) 

		#[ $Enable -eq 0 ] && echo -e "\033[31mRegra: $Cont | $Status\033[0m  | Origem: $OrigemRegra | Destino: $DestinoRegra | Servico: $ServicosRegra | Total: $TotalRegra"
		#[ $Enable -eq 1 ] && echo -e "\033[32mRegra: $Cont |$Status\033[0m  | Origem: $OrigemRegra | Destino: $DestinoRegra | Servico: $ServicosRegra | Total: $TotalRegra"
		[ $Enable -eq 0 ] && echo -e "\033[31m$Cont| $Status\033[0m|$OrigemRegra|$DestinoRegra|$ServicosRegra|$TotalRegra"
		[ $Enable -eq 1 ] && echo -e "\033[32m$Cont|$Status\033[0m|$OrigemRegra|$DestinoRegra|$ServicosRegra|$TotalRegra"
	Total=$(expr $Total + $TotalRegra)
	Cont=$(expr $Cont + 1)
	[ $Enable -eq 0 ] && TotalDisable=$(expr $TotalDisable + $TotalRegra)
	[ $Enable -eq 1 ] && TotalEnable=$(expr $TotalEnable + $TotalRegra)

done 
echo '------------------------------------------------------'
echo -e "\033[32mTotal de Regras Habilita:\033[0m$TotalEnable"
echo -e "\033[31mTotal de Regras Desabilita:\033[0m$TotalDisable"
echo "Total de Regras = $Total")

rm .regras.txt
