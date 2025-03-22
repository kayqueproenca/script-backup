#! /usr/bin/env bash

#CASO QUEIRA DEBBUGAR, DESCOMENTE A LINHA ABAIXO.
#set -x
PS3="->"

#AQUI, É O DIRETÓRIO PAI DAS PASTAS QUE QUEREMOS FAZER O BACKUP, NO MODELO, FAREMOS O BACKUP DE PASTAS QUE ESTÃO NO HOME DO USUÁRIO, ALTERE CONFORME SUA NECESSIDADE.
LOCAL=$HOME

#PASTA DESTINO (LOCAL), PARA ONDE NOSSO BACKUP VAI, ALTERE CONFORME SUA NECESSIDADE.
DESTINO="/mnt/bkp"

#AQUI VAMOS POR O UUID DO DISCO, QUE PODE SER UM HD EXTERNO, OU UM DISCO EXTRA NO PC, AQUI PODEMOS USAR O COMANDO "lsblk -o NAME,UUID".
DISCOID="b16e1331-c486-48d8-872b-a2440240534c"

#VAMOS TER A LISTA DE DIRETÓRIOS QUE PODEMOS FAZER BACKUP, ESSA LISTA PODE SER PERSONALIZADA CONFORME SEU AMBIENTE.
DIRETORIOS=("Músicas" "Vídeos" "Documentos" "Fotos")

#ESSA FUNÇÃO TEM O PAPEL DE VERIFICAR SE O rsync ESTÁ DE FATO INSTALADO, SEM ELE NÃO TEMOS COMO FAZER O PROCEDIMENTO.
teste_rsync(){
 if type rpm &> /dev/null ; then
  DICA="dnf install rsync"
 else
  DICA="apt install rsync"
 fi

 if ! which rsync &> /dev/null ; then
  echo -e "Erro!\nO rsync não está instalado! Rode o ${DICA}"
  exit 1
 else
  teste_disco
 fi
}

#ESSA FUNÇÃO VAI VERIFICAR SE O DISCO EXISTE, COM BASE NO UUID INFORMADO, LEMBRE-SE DE INFORMAR O UUID CERTO, ESSA FUNÇÃO SÓ É CHAMADA SE O teste_rsync NÃO RETORNAR ERRO.
teste_disco(){
 if ! lsblk -o UUID | grep -w -q "$DISCOID" || [ -z "$DISCOID" ]; then
  echo -e "O disco não foi encontrado com base no $DISCOID informado\nDICA: Use o \"lsblk -o NAME,UUID\" para pegar essa informação ;-)"
  exit 1
 fi

 if [ ! -d "$DESTINO" ] ; then
  echo "Não foi possível achar o ${DESTINO}, certifique-se que esteja montado"
  exit 1
 else
  origem
 fi
}

#ESSA FUNÇÃO, É ONDE O USUÁRIO VAI SELECIONAR DE QUAL PASTA, OU CONJUNTO DE PASTAS, VAI SER FEITO O BACK PARA O DESTINO.
origem(){
 clear
 if [ "$PWD" != "$LOCAL" ] ; then
  echo "Rode o comando do diretório $LOCAL"
  exit 1
 else
  echo -e "Selecione o(s) diretório(s) que vamos fazer o backup"
  select OPC in ${DIRETORIOS[@]} "TODOS DA LISTA" ; do
   if [ "$OPC" = "TODOS DA LISTA" ] ; then
    ORIGEM=${DIRETORIOS[@]}
   else
    ORIGEM="${OPC}"
   fi
   break
  done
  for LISTA in ${ORIGEM[@]} ; do
   if [ ! -d $LISTA ] ; then
    echo "Erro! Diretório $LISTA não existe"
    exit 1
   fi
  done
  backup_menu
 fi
}

#ESSA FUNÇÃO FAZ O BACKUP INCREMENTAL, ONDE TUDO DA PASTA VAI SER COPIADO PARA O DESTINO, E SE TIVER ARQUIVO LÁ, ELE VAI SER ATUALIZADO, SE HOUVE MUDANÇA NO MESMO.
comum_tudo(){
cat << EOF
Esse tipo de backup, vai copiar tudo que estiver no diretório selecionado ${ORIGEM[@]}(incluindo ele mesmo), caso já tenha arquivo
ele vai ser preservado, ou atualizado, se houver alguma alteração para o diretório ${DESTINO}

EOF
 read -p "Deseja prosseguir? S/N " RESP
 RESP=${RESP^^}
 if [ $RESP = "S" ] ; then
  for DIRETORIO in ${ORIGEM[@]} ; do
     if ! rsync -a ${DIRETORIO} $DESTINO > /dev/null 2>> erro.log ; then
      echo "Erro ao fazer backup. Veja o arquivo de log"
     else
      echo "Diretório ${DIRETORIO} copiado com sucesso!"
     fi
    done
  else
   backup_menu
 fi
}

#ESSA FUNÇÃO FUNCIONA QUASE DA MESMA FORMA QUE A ANTERIOR, PORÉM, VAI SER QUESTIONADO UM PADRÃO DE CARACTERES, ONDE OS ARQUIVOS QUE BATEM, NÃO VÃO SER COPIADOS.
comum_tira_padrao(){
cat << EOF
Esse tipo de backup vai copiar tudo que estiver no diretório ${ORIGEM[@]}(incluindo ele mesmo), MENOS, um padrão que for informado,
os demais arquivos vão ser copiados para o destino ${DESTINO}, sendo preservados, ou atualizados, caso houver alguma alteração

EOF
 read -p "Deseja continuar? S/N " RESP
 RESP=${RESP^^}
 if [ $RESP = "S" ] ; then
  read -p "Informe qual padrão que NÃO vai ser copiado para ${DESTINO} " PADRAO
   for DIRETORIO in ${ORIGEM[@]} ; do
    if ! rsync -a --exclude="*${PADRAO}*" ${DIRETORIO} ${DESTINO} > /dev/null 2>> erro.log ; then
     echo "Erro ao fazer backup. Veja o arquivo de log"
    else
     echo "Diretório ${DIRETORIO} copiado com sucesso, menos arquivos com $PADRAO no nome"
    fi
   done
  else
   backup_menu
 fi
}

#ESSA FUNÇÃO FAZ UM SINCRONISMO, ALÉM DE COPIAR O QUE É NOVO, ALTERAR O QUE É ANTIGO (SE HOUVER ALTERAÇÃO NA ORIGEM), CASO UM ARQUIVO FOI APAGADO NA ORIGEM, E TENHA CÓPIA NO DESTINO, VAI SER APAGADO TAMBÉM.
sincronismo(){
cat << EOF
Esse tipo de backup vai copiar tudo que estiver no diretório ${ORIGEM[@]}(incluindo ele mesmo), porém, se já tiver um backup anterior feito, e algum arquivo
foi apagado da pasta ORIGEM, então, caso esse arquivo exista no DESTINO, ele vai ser apagado também

EOF
 read -p "Deseja continuar? S/N " RESP
 RESP=${RESP^^}
 if [ "$RESP" = "S" ] ; then
  for DIRETORIO in ${ORIGEM[@]} ; do
   if ! rsync -a --delete ${DIRETORIO} ${DESTINO} > /dev/null 2>> erro.log ; then
     echo "Erro ao fazer backup. Veja o arquivo de log"
   else
     echo "Diretório ${DIRETORIO} copiado com sucesso!"
   fi
  done
 else
  backup_menu
 fi
}

#AQUI VAMOS TER O MENU, ONDE O USUÁRIO VAI SELECIONAR QUAL TIPO DE BACKUP ELE VAI QUERER, NO CASO AS FUNÇÕES ACIMA. 
backup_menu(){
 echo "Diretórios que vão ser copiados: ${ORIGEM[@]}"
 echo "Diretório destino $DESTINO"
 echo "Selecione o tipo de backup:"
 select BKP in "Comum - Tudo" "Comum - Tira algum padrão" "Sincronismo" ;do
  case $REPLY in
   1)
    comum_tudo
    break ;;
   2)
   comum_tira_padrao
   break ;;
   3)
    sincronismo
    break ;;
  esac
 done
}

teste_rsync
