#!/bin/sh
#============================================================================
# Name        : pre_mix.sh
# Version     : 1.0
# Description : File to file Sftp and Ftp (PART1)
# ============================================================================
#################################################
#FILE NAME AND TEMP FILE AND EVERY FILE PATH.	#
#FILE PATH. P1					#
#TEMP FILE. P2					#
#PARAMETERS BACK UP. P3				#
#################################################



#============================================================================
#Functions Instructions:

#EngineStatus:
#JobStatus:
#ResetJob:
#RunJob:
#CheckFile:
#CON_INFO:
#ftp_1_log:
#ftp_2_log:
#ftp_3_log:
#ftp_4_log:
#CALCULATION_FILES_LIST:
#CHKFTP:
#GETFILELIST:
#FNDTGT:
#============================================================================

#p1
LOGDIR=/u03/project/XSCM/DIP2_TEMPLATE/MIX/DEPTLIST
HOST_INFO=/u03/project/XSCM/DIP2_TEMPLATE/MIX/hostinfo
DSLOG=/u03/project/XSCM/DIP2_TEMPLATE/MIX/DSLOG
TRANSDIR=/u03/project/XSCM/DIP2_TEMPLATE/MIX/TRANSLOG
LOGMAILTO='wenwu@mxic.com.tw,jeffhsu@mxic.com.tw'
PROJECT=XSCM
#p2
MAILTEMP=mailtmp_"`date +%Y%m%d%H%M%S`"
TEMPLOG=templog_"`date +%Y%m%d%H%M%S`"
FTPLOG=pre_ftplog_`date +%Y%m%d`
SFTPLOG=pre_sftplog_`date +%Y%m%d`
TIMESTAMP="`date +%Y%m%d%H%M%S`"
#P3
#ken68lee@mxic.com.tw,wenwu@mxic.com.tw,jeffhsu@mxic.com.tw,xscm@twhetld1.macronix.com


#D_F:DATASTAGE FUNCTION

# DataStage Env
. `cat /.dshome`/dsenv > /dev/null 2>&1
# DS Functions
EngineStatus()
{
egstatus=`$DSHOME/bin/uv -info|grep "Engine status"|awk -F[:] '{print $NF}'|sed 's/^[ \t]*//g'`
if  [[ $egstatus == "Not running"  ]]
then
echo 1
else
echo 0
fi
}

JobStatus()
{
status=`$DSHOME/bin/dsjob -jobinfo $1 $2 2>&1 | grep "Job Status" | sed "s/.*(\(.*\))/\1/"`
echo $status
}

ResetJob()
{
touch $DSLOG/$DSLOGFILE
chmod 777 $DSLOG/$DSLOGFILE

echo "$TIMESTAMP------------------------------" >> $DSLOG/$DSLOGFILE > /dev/null 2>&1
echo "JOBNAME="$JOBNAME >> $DSLOG/$DSLOGFILE
job_status=`JobStatus $PROJECT $JOBNAME`
if [ $job_status -eq 3 ]
then
    echo "Resetting Job" >> $DSLOG/$DSLOGFILE
    $DSHOME/bin/dsjob -run -mode RESET $PROJECT $JOBNAME > /dev/null 2>&1
    job_status=$?
    if [ ! $job_status -eq 0 ]
    then
        echo "FATAL ERROR: Reset Job failed" >> $DSLOG/$DSLOGFILE
    fi
fi
}

RunJob()
{
$DSHOME/bin/dsjob -run -warn 0 -mode NORMAL -param runlist=$RUN_LIST -jobstatus $PROJECT $JOBNAME > /dev/null 2>&1
job_status=$?

if [ $job_status -ne 1 -a $job_status -ne 2 ]
then
    echo "Job Failed" >> $DSLOG/$DSLOGFILE
else
    echo "Job Successful" >> $DSLOG/$DSLOGFILE
fi
}




#C_F:Check file type about "all_dir","ctl_file","chg_name","move_all","fixed_file"

CheckFile()
{
S_FILE=$1
S_DIR=$2
S_HOST=$3
CHECK_TYPE=$4
S_ACCOUNT=$5
NEXTJOB_NAME=$6

CHK_FILE=$S_DIR/$S_FILE
echo "=======================" >&2
echo "Start Check Files">&2

echo CHKFILE=$CHK_FILE >&2
if [[ $CHECK_TYPE == "all_dir" ]] 
then
  echo "Files Type: all_dir" >&2
  CHK_FILE=$S_DIR/complete.txt
  CHKFTP $CHK_FILE $S_HOST $S_ACCOUNT >&2
elif [[ $CHECK_TYPE == "ctl_file" ]]
then
  echo "Files Type: ctl_file"
  CHK_DIR=$S_DIR/../ctl/*.ctl
  echo chk_dir change to $CHK_DIR >&2
  GETFILELIST $CHK_DIR $S_HOST $S_ACCOUNT >&2
elif [[ $CHECK_TYPE == "chg_name" ]]
then
  echo "Files Type: chg_name" >&2
  GETFILELIST $S_DIR $S_HOST $S_ACCOUNT $S_FILE>&2
  FNDTGT $S_DIR $S_HOST $CHECK_TYPE $S_ACCOUNT >&2
elif [[ $CHECK_TYPE == "move_all" ]]
then
  echo "Files Type: move_all" >&2
  GETFILELIST $S_DIR $S_HOST $S_ACCOUNT $S_FILE>&2
  FNDTGT $S_DIR $S_HOST $CHECK_TYPE $S_ACCOUNT $NEXTJOB_NAME>&2
elif [[ $CHECK_TYPE == "fixed_file" ]]
then
  echo "Files Type: fixed_file" >&2
  GETFILELIST $S_DIR $S_HOST $S_ACCOUNT $S_FILE>&2
  FNDTGT $S_DIR $S_HOST $CHECK_TYPE $S_ACCOUNT $NEXTJOB_NAME>&2
else
   echo "`date`  Parameter error!" >&2
   echo 1
   exit 
fi

# TEST Flag Result
# If the flag file size is GT 0, means the file is arrived
FILESIZE=`stat -c%s $LOGDIR/$FLAG`
echo "Check list and File size">&2
echo FILESIZE=$FILESIZE >&2

if [[ $FILESIZE -eq 0 ]]
then
	echo 1
else
	echo 0 
	if [[ $CHECK_TYPE == "all_dir" ]] 
	then
		GETFILELIST $S_DIR $S_HOST $S_ACCOUNT 
	fi 
fi
echo "End Check files">&2
echo "=======================" >&2
echo "">&2
echo "">&2
echo "">&2
echo "">&2
}

CON_INFO()
{
while read -r line
do
ACCT=$(echo $line |awk '{print $2}')
if [[ $ACCT == $S_ACCOUNT ]]
then
H_IP=$(echo $line | awk '{print $1}')
H_ACT=$(echo $line | awk '{print $2}')
H_PWD=$(echo $line | awk '{print $3}')
fi
done < $HOST_INFO/$S_HOST


}




ftp_1_log()
{
#ftp_1
echo "=======================" >&2
echo "ftp_1 get list."
ftp -i -n -v $H_IP <<EOF > $TRANSDIR/$TEMPLOG
quote USER $S_ACCOUNT
quote PASS $H_PWD
prompt
ls $CHK_FILE $LOGDIR/$FLAG
quit
EOF
echo $CHK_FILE $LOGDIR/$FLAG
echo $TRANSDIR/$TEMPLOG
#grep ftp
echo "ftp_1 write log."
grep -w -E "202|332|350|400|421|425|426|450|451|452|500|501|502|503|504|530|532|550|552|553|Not connected|No such file or directory|failed to open" $TRANSDIR/$TEMPLOG|grep -v "bytes"|grep -v "Trying " >$TRANSDIR/$MAILTEMP 2>&1
FSIZE=`stat -c%s $TRANSDIR/$MAILTEMP`
if [[ $FSIZE -gt 0 ]]
then
  echo "ftp_1 CHKFTP check error. [pre_ftp]JOB:$JOBNAME  [pre_ftp]host:$S_HOST [pre_ftp]FILEDIR:$CHK_FILE"
  echo -e "\n $TIMESTAMP-----------------------------------------------------------">>$TRANSDIR/$FTPLOG 2>&1
  echo "START" >>$TRANSDIR/$FTPLOG 2>&1
  echo "ftp_1 CHKFTP check error. [pre_ftp]JOB:$JOBNAME  [pre_ftp]host:$S_HOST [pre_ftp]FILEDIR:$CHK_FILE" >>$TRANSDIR/$FTPLOG 2>&1
`cat $TRANSDIR/$TEMPLOG >> $TRANSDIR/$FTPLOG`
  echo "END">>$TRANSDIR/$FTPLOG 2>&1
echo ftp_1 end
echo "=================================================================="
#echo -e "[pre_ftp]ftp error code,\nJOB:$JOBNAME,\nhost:$S_HOST,\nFILEDIR:$CHK_FILE" | mail -s "[pre_ftp]ftp error code,JOB:$JOBNAME,FILEDIR:$CHK_FILE" -t $LOGMAILTO
else
  echo "ftp_1 CHKFTP check ok,[pre_ftp]JOB:$JOBNAME,[pre_ftp]host:$S_HOST,[pre_ftp]FILEDIR:$CHK_FILE "
  echo -e "\n $TIMESTAMP-----------------------------------------------------------">>$TRANSDIR/$FTPLOG 2>&1
  echo "START" >>$TRANSDIR/$FTPLOG 2>&1
  echo "ftp_1 CHKFTP check ok,[pre_ftp]JOB:$JOBNAME,[pre_ftp]host:$S_HOST,[pre_ftp]FILEDIR:$CHK_FILE " >> $TRANSDIR/$FTPLOG
`cat $TRANSDIR/$TEMPLOG >> $TRANSDIR/$FTPLOG`
  echo "END">>$TRANSDIR/$FTPLOG 2>&1
fi
echo ftp_1 end
echo "=======================" >&2
echo "----------------------------------------------------------------------------------------"
}


ftp_2_log()
{

ftp -i -n $H_IP <<EOF >$TRANSDIR/$TEMPLOG
quote USER $S_ACCOUNT
quote PASS $H_PWD
prompt
ls $S_DIR $LOGDIR/$FLAG
quit
EOF

echo "=======================" >&2
echo "ftp_2 write log" >&2
grep -w -E "202|332|350|400|421|425|426|450|451|452|500|501|502|503|504|530|532|550|552|553|Not connected|Please login with USER and PASS|No such file or directory|failed to open" $TRANSDIR/$TEMPLOG|grep -v "bytes"|grep -v "complete.txt"|grep -v "Trying "|grep -v 'Binary file '|grep -v 'complete.txt' > $TRANSDIR/$MAILTEMP 2>&1
sed -i '/complete.txt/d' $TRANSDIR/$MAILTEMP
FSIZE=`stat -c%s $TRANSDIR/$MAILTEMP`
        if [[ $FSIZE -gt 0 ]]
        then
                echo -e "\n $TIMESTAMP-----------------------------------------------------------">>$TRANSDIR/$FTPLOG
                echo "START" >>$TRANSDIR/$FTPLOG
                echo "ftp_2 GETFILELIST error [pre_ftp]JOB:$JOBNAME [pre_ftp]host:$S_HOST [pre_ftp]FILEDIR:$S_DIR" >>$TRANSDIR/$FTPLOG
`cat $TRANSDIR/$TEMPLOG >> $TRANSDIR/$FTPLOG`
                echo "END">>$TRANSDIR/$FTPLOG 2>&1
                mail -s "ftp_2 GETFILELIST error.[pre_ftp]JOB:$JOBNAME [pre_ftp]host:$S_HOST [pre_ftp]FILEDIR:$S_DIR/$S_FILE" $LOGMAILTO<$TRANSDIR/$MAILTEMP
        else
                echo -e "\n $TIMESTAMP-----------------------------------------------------------">>$TRANSDIR/$FTPLOG
                echo "START" >>$TRANSDIR/$FTPLOG
                echo "ftp_2 get GETFILELIST ok,[pre_ftp]JOB:$JOBNAME,[pre_ftp]host:$S_HOST,[pre_ftp]FILEDIR:$S_DIR" >>$TRANSDIR/$FTPLOG
		echo "ftp_2 get GETFILELIST ok,[pre_ftp]JOB:$JOBNAME,[pre_ftp]host:$S_HOST,[pre_ftp]FILEDIR:$S_DIR">&2
`cat $TRANSDIR/$TEMPLOG >> $TRANSDIR/$FTPLOG`
                echo "END">>$TRANSDIR/$FTPLOG
        fi
echo "ftp_2 end">&2
echo "=======================" >&2
echo "----------------------------------------------------------------------------------------">&2
}


ftp_3_log()
{
#ftp_3
ftp -i -n $H_IP <<EOF >$TRANSDIR/$TEMPLOG
quote USER $S_ACCOUNT
quote PASS $H_PWD
prompt
ls $S_DIR/$S_FILE $LOGDIR/$FLAG
quit
EOF

echo "=======================" >&2
echo "ftp_3 write log."

grep -w -E "202|332|350|400|421|425|426|450|451|452|500|501|502|503|504|530|532|550|552|553|Not connected|Please login with USER and PASS|No such file or directory" $TRANSDIR/$TEMPLOG |grep -v "bytes"|grep -v "complete.txt" > $TRANSDIR/$MAILTEMP 2>&1

FSIZE=`stat -c%s $TRANSDIR/$MAILTEMP`
        if [[ $FSIZE -gt 0 ]]
        then
                echo -e "\n $TIMESTAMP-----------------------------------------------------------">>$TRANSDIR/$FTPLOG
                echo "START" >>$TRANSDIR/$FTPLOG
                echo "ftp_3 GETFILELIST  error [pre_ftp]JOB:$JOBNAME [pre_ftp]host:$S_HOST [pre_ftp]FILEDIR:$S_DIR" >>$TRANSDIR/$FTPLOG
		echo "ftp_3 GETFILELIST  error [pre_ftp]JOB:$JOBNAME [pre_ftp]host:$S_HOST [pre_ftp]FILEDIR:$S_DIR">&2
                `cat $TRANSDIR/$TEMPLOG >> $TRANSDIR/$FTPLOG`
                echo "END">>$TRANSDIR/$FTPLOG
                mail -s "ftp_3 GETFILELIST error.[pre_ftp]JOB:$JOBNAME [pre_ftp]host:$S_HOST [pre_ftp]FILEDIR:$S_DIR" $LOGMAILTO<$TRANSDIR/$MAILTEMP
        else
                echo  -e "\n $TIMESTAMP-----------------------------------------------------------">>$TRANSDIR/$FTPLOG
                echo "START" >>$TRANSDIR/$FTPLOG
                echo "ftp_3 get GETFILELIST ok [pre_ftp]JOB:$JOBNAME,[pre_ftp]host:$S_HOST,[pre_ftp]FILEDIR:$S_DIR" >>$TRANSDIR/$FTPLOG
		echo "ftp_3 get GETFILELIST ok [pre_ftp]JOB:$JOBNAME,[pre_ftp]host:$S_HOST,[pre_ftp]FILEDIR:$S_DIR" >&2
                `cat $TRANSDIR/$TEMPLOG >> $TRANSDIR/$FTPLOG`
                echo "END">>$TRANSDIR/$FTPLOG
        fi

echo "ftp_3 end">&2
echo "=======================" >&2
echo "----------------------------------------------------------------------------------------"
}


ftp_4_log()
{
#ftp_4
   ftp -i -n  $H_IP  <<EOF > $LOGDIR/$FTP_LOG
   quote USER $S_ACCOUNT
   quote PASS $H_PWD
   rename $S_DIR/$F_NAME $S_DIR/$NEW_NAME
   quit
EOF
#check file return code


echo "=======================" >&2
echo "ftp_4 rename files"

grep -w -E "202|332|350|400|421|425|426|450|451|452|500|501|502|503|504|530|532|550|552|553|Not connected|Please login with USER and PASS|No such file or directory|The system cannot find the file specified" $LOGDIR/$FTP_LOG|grep -v "bytes" >$TRANSDIR/$MAILTEMP 2>&1

LOGSIZE=`stat -c%s $TRANSDIR/$MAILTEMP`
if [[ $LOGSIZE -gt 0 ]]
   then
        echo -e "\n $TIMESTAMP-----------------------------------------------------------">>$TRANSDIR/$FTPLOG
        echo "START" >>$TRANSDIR/$FTPLOG
        echo "ftp_4 FNDTGT rename error [pre_ftp]JOB:$JOBNAME [pre_ftp]host:$S_HOST [pre_ftp]FILEDIR:$S_DIR/$F_NAME" >>$TRANSDIR/$FTPLOG
        `cat $TRANSDIR/$TEMPLOG >> $TRANSDIR/$FTPLOG`
        echo "END">>$TRANSDIR/$FTPLOG
        mail -s "ftp_4 FNDTGT rename error code.[pre_ftp]JOB:$JOBNAME/$NEXTJOB_NAME [pre_ftp]host:$S_HOST [pre_ftp]FILEDIR:$S_DIR/$F_NAME" $LOGMAILTO<$TRANSDIR/$MAILTEMP
   else
        echo -e "\n $TIMESTAMP-----------------------------------------------------------">>$TRANSDIR/$FTPLOG
        echo "START" >>$TRANSDIR/$FTPLOG
        echo -e "ftp_4 FNDTGT rename ok [pre_ftp]JOB:$JOBNAME,[pre_ftp]host:$S_HOST,[pre_ftp]FILEDIR:$S_DIR/$F_NAME" >> $TRANSDIR/$FTPLOG
        `cat $TRANSDIR/$TEMPLOG >> $TRANSDIR/$FTPLOG`
        echo "END">>$TRANSDIR/$FTPLOG
fi
rm $TRANSDIR/$MAILTEMP
echo "End ftp_4 rename files">&2
echo "=======================" >&2
echo "----------------------------------------------------------------------------------------"
 
}



CALCULATION_FILES_LIST()
{
#F_LIST
if [ -f $LOGDIR/$F_LIST  ]
        then
        #echo 0
        CntFLIST=$(echo -e `wc -l $LOGDIR/$F_LIST | awk '{print $1}'` $'\n')
        echo "FLIST exists" >&2
else
        #echo 1
        CntFLIST=0
        echo "FLIST not exists">&2
fi

#R_LIST
if [ -f $LOGDIR/$R_LIST  ]
        then
        #echo 0
        CntRLIST=$(echo -e `wc -l $LOGDIR/$R_LIST | awk '{print $1}'` $'\n')
        echo "RLIST exists" >&2
else
        #echo 1
        CntRLIST=0
        echo "RLIST not exists">&2
fi

#runlist
CntRUNLIST=$(echo `wc -l $LOGDIR/$RUN_LIST | awk '{print $1}'`)
if [ -f $LOGDIR/$RUN_LIST  ]
        then
        #echo 0
	CntRUNLIST=$(echo -e `wc -l $LOGDIR/$RUN_LIST | awk '{print $1}'` $'\n')
        echo "RUN_LIST exists" >&2
else
        #echo 1
        CntRUNLIST=0
        echo "RUN_LIST not exists">&2
fi


CntRRF=$(echo "$CntFLIST + $CntRLIST + $CntRUNLIST" | bc)
echo CntRRF=$CntRRF


}

CHKFTP()
{
CHK_FILE=$1
S_HOST=$2
S_ACCOUNT=$3

# Source connect information Get Host Info
CON_INFO
rm $LOGDIR/$FLAG >&2
touch $LOGDIR/$FLAG >&2
touch $TRANSDIR/$TEMPLOG >&2
touch  $TRANSDIR/$FTPLOG >&2
chmod 777 $LOGDIR/$FLAG >&2
chmod 777 $TRANSDIR/$TEMPLOG >&2 
chmod 777 $TRANSDIR/$FTPLOG >&2


echo "==========================================================="
echo "CHEKFTP"

if [ $S_ROAD == "FTP"  ]
then
#ftp_1: Get FTP type Files list and write log to FTPLOG.
ftp_1_log  #記得後面的log也要加上"failed to open"加以辨識
else
#sftp_1
touch  $TRANSDIR/$SFTPLOG
chmod 775 $TRANSDIR/$SFTPLOG

sftp -i ~/.ssh/$H_KWD $S_ACCOUNT@$H_IP <<EOF > $TRANSDIR/$TEMPLOG #$LOGDIR/$FLAG
ls -l $CHK_FILE
quit
EOF
sed -i '1d' $TRANSDIR/$TEMPLOG
sed -i '$d' $TRANSDIR/$TEMPLOG
`cp $TRANSDIR/$TEMPLOG $TRANSDIR/$SFTPLOG`

  echo -e "\n $TIMESTAMP-----------------------------------------------------------">>$TRANSDIR/$SFTPLOG 2>&1
  echo "START" >>$TRANSDIR/$SFTPLOG 2>&1
  echo "sftp_1 CHKFTP check ok, [pre_sftp]JOB:$JOBNAME [pre_sftp]host:$S_HOST [pre_sftp]FILEDIR:$CHK_FILE" >>$TRANSDIR/$SFTPLOG 2>&1
`cat $TRANSDIR/$TEMPLOG >> $TRANSDIR/$SFTPLOG`
  echo "END">>$TRANSDIR/$SFTPLOG 2>&1

fi


rm $TRANSDIR/$TEMPLOG
rm $TRANSDIR/$MAILTEMP
echo "End CHEKFTP "
echo "==========================================================="
}





#get file list
GETFILELIST()
{
S_DIR=$1
S_HOST=$2
S_ACCOUNT=$3
S_FILE=$4

echo "==========================================================="
echo "Start GETFILELIST"
## Get Host Info
CON_INFO
#/dev/null 2>&1
touch $LOGDIR/$FLAG
touch $TRANSDIR/$TEMPLOG >&2
chmod 777 $LOGDIR/$FLAG  >&2
chmod 777 $TRANSDIR/$TEMPLOG >&2

if [[  $S_FILE == "ALL"  ]]
then
    if [ $S_ROAD == "FTP"  ]
    then
        #ftp_2
	#get files list inside.
        ftp_2_log
    else
#sftp_2
sftp -i ~/.ssh/$H_KWD $H_ACT@$H_IP <<EOF >$LOGDIR/$FLAG
ls -l $S_DIR
quit
EOF
sed -i '1d' $LOGDIR/$FLAG
sed -i '$d' $LOGDIR/$FLAG
                echo -e "\n $TIMESTAMP-----------------------------------------------------------">>$TRANSDIR/$SFTPLOG
                echo "START" >>$SFTPDIR/$SFTPLOG
                echo "sftp LOG [pre_sftp]JOB:$JOBNAME [pre_sftp]host:$S_HOST [pre_sftp]FILEDIR:$S_DIR" >>$TRANSDIR/$SFTPLOG
		#`cat $SFTPDIR/$FILELOG >> $SFTPDIR/$SFTPLOG`
                echo "END">>$TRANSDIR/$SFTPLOG 2>&1

fi
else

    if [ $S_ROAD == "FTP"  ]
    then
	#ftp_3
        ftp_3_log
    else
#sftp_3
ftp -i ~/.ssh/$H_KWD $H_ACT@$H_IP <<EOF >$TRANSDIR/$FLAG
ls -l  $S_DIR/$S_FILE
quit
EOF
sed -i '1d' $TRANSDIR/$FLAG
sed -i '$d' $TRANSDIR/$FLAG

                echo -e "\n $TIMESTAMP-----------------------------------------------------------">>$TRANSDIR/$SFTPLOG
                echo "START" >>$SFTPDIR/$SFTPLOG
                echo "sftp ls  error [pre_sftp]JOB:$JOBNAME [pre_sftp]host:$S_HOST [pre_sftp]FILEDIR:$S_DIR/$S_FILE" >>$TRANSDIR/$SFTPLOG
                #`cat $SFTPDIR/$FILELOG >> $SFTPDIR/$SFTPLOG`
                echo "END">>$TRANSDIR/$SFTPLOG


     fi
fi
rm $TRANSDIR/$TEMPLOG
rm $TRANSDIR/$MAILTEMP
echo "End GETFILELIST"
echo "==========================================================="
echo ""
echo ""
echo ""
echo ""
}






FNDTGT()
{
S_DIR=$1
S_HOST=$2
CHECK_TYPE=$3
S_ACCOUNT=$4
NEXTJOB_NAME=$5
#chmod 777 $LOGDIR/$R_LIST >&2


echo "===========================================================">&2
echo "Start FNDTGT grep need files and control files number.">&2



if [ $S_ROAD == "FTP" ]
then
echo "Source FTP:"
echo "----------"
	if [[ $CHECK_TYPE == "chg_name" ]]
	then
	echo "CHECK_TYPE: chg_name"
    		grep -v "<DIR>" $LOGDIR/$FLAG|grep -v prs_|grep -v fin_|grep -v stg_|grep -v total |grep -v ^'\<drw'|grep -v '\.\.'|awk '{print $NF}' > $LOGDIR/$R_LIST

	elif [[ $CHECK_TYPE == "move_all"  ]]&&[[ $NEXTJOB_NAME == "Sjob_MES_MxtranPO_ASEQ"  ]]
	then
	echo "CHECK_TYPE: move_all and NEXTJOB_NAME: Sjob_MES_MxtranPO_ASEQ"
 	grep -v "<DIR>" $LOGDIR/$FLAG|grep -v ^'\<drw'|grep -v prs_|grep -v stg_|grep MXIC_|awk '{print $NF}' > $LOGDIR/$R_LIST

	elif [[ $CHECK_TYPE == "fixed_file"  ]]&&[[ $NEXTJOB_NAME == "Sjob_MEP_WIP_Data_ASEQ"  ]]
	then
	echo "CHECK_TYPE: fixed_file and NEXTJOB_NAME: Sjob_MEP_WIP_Data_ASEQ"
touch $LOGDIR/$F_LIST
chmod 777 $LOGDIR/$F_LIST
 	grep -v "<DIR>" $LOGDIR/$FLAG|grep -v prs_|grep -v fin_|grep -v stg_|grep -v ^'\<drw'|grep $DATE|awk '{print $NF}' > $LOGDIR/$F_LIST

	elif [[ $CHECK_TYPE == "fixed_file"  ]]
	echo "CHECK_TYPE: fixed_file"
	then
touch $LOGDIR/$F_LIST
chmod 777 $LOGDIR/$F_LIST
 	grep -v "<DIR>" $LOGDIR/$FLAG|grep -v prs_|grep -v fin_|grep -v stg_|grep -v ^'\<drw'|awk '{print $NF}' > $LOGDIR/$F_LIST
	else
 	grep -v "<DIR>" $LOGDIR/$FLAG|grep -v ^'\<drw'|grep -v prs_|grep -v stg_|awk '{print $NF}' > $LOGDIR/$R_LIST

	fi

else
echo "Source SFTP:"
echo "----------"
	if [[ $CHECK_TYPE == "chg_name" ]]
	echo "CHECK_TYPE: chg_name"
	then
   	grep -v "<DIR>" $LOGDIR/$FLAG|grep -v prs_|grep -v fin_|grep -v stg_|grep -v total |grep -v ^'\<drw'|grep -v '\.\.'|awk '{print $NF}' > $LOGDIR/$R_LIST
	elif [[ $CHECK_TYPE == "move_all"  ]]&&[[ $NEXTJOB_NAME == "Sjob_MES_MxtranPO_ASEQ"  ]]
	then
	echo "CHECK_TYPE: move_all and NEXTJOB_NAME: Sjob_MES_MxtranPO_ASEQ"
 	grep -v "<DIR>" $LOGDIR/$FLAG|grep -v ^'\<drw'|grep -v prs_|grep -v stg_|grep MXIC_|awk '{print $NF}' > $LOGDIR/$R_LIST
elif [[ $CHECK_TYPE == "fixed_file"  ]]&&[[ $NEXTJOB_NAME == "Sjob_MEP_WIP_Data_ASEQ"  ]]
	then
	echo "CHECK_TYPE: fixed_file and NEXTJOB_NAME: Sjob_MEP_WIP_Data_ASEQ"
touch $LOGDIR/$F_LIST
chmod 777 $LOGDIR/$F_LIST
 	grep -v "<DIR>" $LOGDIR/$FLAG|grep -v prs_|grep -v fin_|grep -v stg_|grep -v ^'\<drw'|grep $DATE|awk '{print $NF}' > $LOGDIR/$F_LIST
	elif [[ $CHECK_TYPE == "fixed_file"  ]]
	then
	echo "CHECK_TYPE: fixed_file"
touch $LOGDIR/$F_LIST
chmod 777 $LOGDIR/$F_LIST
 	grep -v "<DIR>" $LOGDIR/$FLAG|grep -v prs_|grep -v fin_|grep -v stg_|grep -v ^'\<drw'|awk '{print $NF}' > $LOGDIR/$F_LIST
	else
 	grep -v "<DIR>" $LOGDIR/$FLAG|grep -v ^'\<drw'|grep -v prs_|grep -v stg_|awk '{print $NF}' > $LOGDIR/$R_LIST

	fi
fi
echo "End FNDTGT grep need files and control files number."
echo "----------------"

#check chg if more then 20 row
#first Calculation F_LIST and F_LIST total files
#ntRLIST
#All files must less more then 20
echo "Start control files numbers.">&2
CALCULATION_FILES_LIST  #Count all list. (R_LIST,F_LIST,runlist) #Para(CntFLIST,CntRLIST,CntRUNLIST,CntRRF)


Result=$(echo 20 - $CntRRF|bc)
if [ $CntRUNLIST -ge 20  ]
then
   if [ -f $LOGDIR/$R_LIST ]
   then
	sed -i '1,$d' $LOGDIR/$R_LIST
   else
	echo "R_LIST not exist"
   fi

   if [ -f $LOGDIR/$F_LIST ]
   then
	sed -i '1,$d' $LOGDIR/$F_LIST
   else
	echo "F_LIST not exist"
   fi

elif [ $CntRUNLIST -ge 0  ] && [ $CntRUNLIST -le 20  ]
then
#如果runlist>=0 and runlist <=20,會把超過10行(需要rename)以後的新增行刪除,最多保留29行
   if [ -f $LOGDIR/$R_LIST ]
   then
	sed -i '10,$d' $LOGDIR/$R_LIST
   else
	echo "R_LIST not exist"
   fi

   if [ -f $LOGDIR/$F_LIST ]
   then
	sed -i '10,$d' $LOGDIR/$F_LIST
   else
	echo "F_LIST not exist"
   fi
echo "End control files numbers.">&2


#####################################################################################
#為了驗證R_LIST和F_LIST結果是否輔和要求和建立,之後可與Chk_R_list資料夾一起刪除
echo ""
echo"#######"
if [ -f $LOGDIR/$R_LIST  ]
then
cp $LOGDIR/$R_LIST /u03/project/XSCM/DIP2_TEMPLATE/MIX/Chk_R_list/$R_LIST_$TIMESTAMP
else
echo "no"
fi
if [ -f $LOGDIR/$F_LIST  ]
then
cp $LOGDIR/$F_LIST /u03/project/XSCM/DIP2_TEMPLATE/MIX/Chk_R_list/$F_LIST_$TIMESTAMP
else
echo "no"
fi
echo"#######"
echo""
#####################################################################################


touch $TRANSDIR/$FTPLOG >&2
chmod 777 $TRANSDIR/$FTPLOG >&2
touch $LOGDIR/$REN_LIST
chmod 777 $LOGDIR/$REN_LIST


# Get Host Info
CON_INFO

touch $LOGDIR/$FTP_LOG
chmod 777 $LOGDIR/$FTP_LOG

if [[ $CHECK_TYPE == "chg_name" ]] || [[ $CHECK_TYPE == "move_all" ]]
then

#Check file is avaliable for rename (check file if complete
while IFS='' read -r list
do

   F_NAME=$list
   TIME_NOW=`date +%Y%m%d%H%M%S`
   NEW_NAME=stg_${F_NAME}_${TIME_NOW}
#ftp_4
#ftp source file and reanme files
   ftp_4_log

   RENAMESIZE=`stat -c%s $LOGDIR/$R_LIST`
   if [[ $CHECK_TYPE == "chg_name" ]]
      then 
         echo "$NEW_NAME $F_NAME " >> $LOGDIR/$REN_LIST
   elif [[ $CHECK_TYPE == "move_all" ]]
      then  
         echo "$NEW_NAME $F_NAME " >> $LOGDIR/$REN_LIST
   fi

done < $LOGDIR/$R_LIST
fi
fi

echo "End FNDTGT grep need files and control files number.">&2
echo "===========================================================">&2
echo ""
echo ""
echo ""
echo ""

}

#FUNCTION END#################################################



###############################
#      Shell Start Here       #
###############################
echo start
FILELIST=$1
EGNSTATUS=`EngineStatus`
if [[ $EGNSTATUS -eq 0 ]]
then

#Check Datastage running or not.
channel=$(echo $FILELIST |awk -F [._] '{print $1}')
interval=$(echo $FILELIST |awk -F [._] '{print $2}')
project=XSCM
jobname=Seq_F2F_${channel}_${interval}
#chkjob_status=`JobStatus $project $jobname`
chkjob_status=1
if [ $chkjob_status -eq 0 ]
then
echo 'Datastage still running.wailt next time please.'
echo 'End'
exit
else

while read -r line
do
   echo line=$line

   CHANNAL=$(echo $line | awk '{print $1}')
   S_FILE=$(echo $line | awk '{print $2}')
   S_DIR=$(echo $line | awk '{print $3}')
   S_HOST=$(echo $line | awk '{print $4}')
   S_ACCOUNT=$(echo $line | awk '{print $5}')
   S_PASSWD=$(echo $line | awk '{print $6}')
   CHCK_TYPE=$(echo $line | awk '{print $7}')
   CHK_INTERVAL=$(echo $line | awk '{print $8}')

   T_FILE=$(echo $line | awk '{print $9}')
   T_DIR=$(echo $line | awk '{print $10}')
   T_HOST=$(echo $line | awk '{print $11}')
   T_ACCOUNT=$(echo $line | awk '{print $12}')
   T_PASSWD=$(echo $line | awk '{print $13}')

   MAIL_TO=$(echo $line | awk '{print $14}')
   TARGET_TYPE=$(echo $line | awk '{print $15}')
   NEXTJOB_NAME=$(echo $line | awk '{print $16}')
   MQ_FILTER=$(echo $line | awk '{print $17}')
   MQ_NAME=$(echo $line | awk '{print $18}')
   JOB_ID=$(echo $line | awk '{print $19}')
   LOCAL_DIR=$(echo $line | awk '{print $20}')
   S_ROAD=$(echo $line | awk '{print $21}')
   T_ROAD=$(echo $line | awk '{print $22}')


   DSLOGFILE="`date +%F`"RUN_$CHANNAL_$CHK_INTERVAL.log
   FLAG=flag_$CHANNAL.$CHK_INTERVAL
   R_LIST=ren_list_$CHANNAL.$CHK_INTERVAL
   FTP_LOG=ftp_log_$CHANNAL.$CHK_INTERVAL
   N_LIST=namelist_$CHANNAL.$CHK_INTERVAL
   C_LIST=ctlfile_$CHANNAL.$CHK_INTERVAL
   F_LIST=fixedfile_$CHANNAL.$CHK_INTERVAL
   RUN_LIST=runlist_$CHANNAL.$CHK_INTERVAL
   REN_LIST=rename_$CHANNAL.$CHK_INTERVAL
   DATE=`date +%Y%m%d%H`
   PROJECT=XSCM
   JOBNAME=Seq_F2F_${CHANNAL}_${CHK_INTERVAL}
   echo JOBNAME=Seq_F2F_${CHANNAL}_${CHK_INTERVAL} >&2

#check  runlist less then 20
touch $LOGDIR/$RUN_LIST
chmod 775 $LOGDIR/$RUN_LIST

CntRUN_LIST=`wc -l $LOGDIR/$RUN_LIST | awk '{print $1}'`

if [ $CntRUN_LIST -ge 20  ]
then
echo "The Files more then 20 row."
echo "end"
else
#get passwd
echo "The Files is less then 20 row."
echo "Keep going"
echo "=="
echo "=="
   echo "Start check Files Type."
   status=`CheckFile $S_FILE $S_DIR $S_HOST $CHCK_TYPE $S_ACCOUNT $NEXTJOB_NAME`
   echo status=$status >&2 
  echo "End check Files Type."

#get S_HOST S_ACCOUNT Informations
CON_INFO

############################################################
while read -r tline
do
TACCT=$(echo $tline |awk '{print $2}')
if [[ $TACCT == $T_ACCOUNT ]]
then
T_IP=$(echo $tline | awk '{print $1}')
T_ACT=$(echo $tline | awk '{print $2}')
T_PWD=$(echo $tline | awk '{print $3}')
fi
done < $HOST_INFO/$T_HOST

   ##Prepare Running List
   if [[ $status -eq 0 ]]
   then
        echo "Running List: chktype=$CHCK_TYPE" >&2 
	if [[ $CHCK_TYPE == "all_dir" ]] 
	then
      	  grep -v "<DIR>"|grep -v ^'\<drw'|grep -v "complete.txt" $LOGDIR/$FLAG > $LOGDIR/$N_LIST 
      	 
          while IFS='' read -r list 
          do
	     F_NAME=$(echo $list |awk '{print $NF}')
             echo "$F_NAME  $S_DIR  $S_HOST  $S_ACCOUNT  $S_PWD  $CHCK_TYPE  $F_NAME  $T_DIR  $T_HOST  $T_ACCOUNT  $T_PWD  $MAIL_TO  $TARGET_TYPE  $NEXTJOB_NAME  $MQ_FILTER  $MQ_NAME  $JOB_ID  $LOCAL_DIR  " >> $LOGDIR/$RUN_LIST 
      	  done < $LOGDIR/$N_LIST
	elif [[ $CHCK_TYPE == "ctl_file" ]] 
	then
      	 # grep -v "<DIR>" $LOGDIR/$FLAG > $C_LIST
		touch $LOGDIR/$C_LIST >&2
		chmod 777 $LOGDIR/$C_LIST >&2 
      	  sed "s/.ctl//g" $LOGDIR/$FLAG > $LOGDIR/$C_LIST
          while IFS='' read -r list 
          do
	     F_NAME=$(echo $list |awk '{print $NF}') 
             echo "$F_NAME  $S_DIR  $S_HOST  $S_ACCOUNT  $S_PWD  $CHCK_TYPE  $F_NAME  $T_DIR  $T_HOST  $T_ACCOUNT  $T_PWD  $MAIL_TO  $TARGET_TYPE  $NEXTJOB_NAME  $MQ_FILTER  $MQ_NAME  $JOB_ID  $LOCAL_DIR  " >> $LOGDIR/$RUN_LIST 
      	  done < $LOGDIR/$C_LIST
		rm -rf $LOGDIR/$C_LIST
		rm -rf $LOGDIR/$FLAG
	elif [[ $CHCK_TYPE == "chg_name" ]] 
	then
		FLAGSZ=`stat -c%s $LOGDIR/$FLAG`
		if [[ $FLAGSZ -ne  0 ]]
		then	
          while IFS='' read -r list
          do
             NEW_NAME=$(echo $list |awk '{print $1}')
             F_NAME=$(echo $list |awk '{print $2}')
             echo "$F_NAME  $S_DIR  $S_HOST  $S_ACCOUNT  $S_PWD  $CHCK_TYPE  $NEW_NAME  $T_DIR  $T_HOST  $T_ACCOUNT  $T_PWD  $MAIL_TO  $TARGET_TYPE  $NEXTJOB_NAME  $MQ_FILTER  $MQ_NAME  $JOB_ID  $LOCAL_DIR  " >> $LOGDIR/$RUN_LIST 
          done < $LOGDIR/$REN_LIST
	  	rm -rf $LOGDIR/$REN_LIST
	  	rm -rf $LOGDIR/$FTP_LOG
	  	rm -rf $LOGDIR/$R_LIST
		rm -rf $LOGDIR/$FLAG
		touch $LOGDIR/$FLAG 
		else
		continue
		fi
	elif [[ $CHCK_TYPE == "move_all" ]] 
	then
          while IFS=''  read -r list
          do
             NEW_NAME=$(echo $list |awk '{print $1}')
             F_NAME=$(echo $list |awk '{print $2}')
	     	
             echo "$F_NAME  $S_DIR  $S_HOST  $S_ACCOUNT  $S_PWD  $CHCK_TYPE  $NEW_NAME  $T_DIR  $T_HOST  $T_ACCOUNT  $T_PWD  $MAIL_TO  $TARGET_TYPE  $NEXTJOB_NAME  $MQ_FILTER  $MQ_NAME  $JOB_ID  $LOCAL_DIR  " >> $LOGDIR/$RUN_LIST
          done < $LOGDIR/$REN_LIST
	  	rm -rf $LOGDIR/$FTP_LOG
	  	rm -rf $LOGDIR/$REN_LIST
	  	rm -rf $LOGDIR/$R_LIST
	elif [[ $CHCK_TYPE == "fixed_file" ]]
        then
          while IFS=''  read -r list
          do
	     FIXED_NAME=$(echo $list |awk '{print $NF}')
             echo "$FIXED_NAME  $S_DIR  $S_HOST  $S_ACCOUNT  $S_PWD  $CHCK_TYPE  $FIXED_NAME  $T_DIR  $T_HOST  $T_ACCOUNT  $T_PWD  $MAIL_TO  $TARGET_TYPE  $NEXTJOB_NAME  $MQ_FILTER  $MQ_NAME  $JOB_ID  $LOCAL_DIR  " >> $LOGDIR/$RUN_LIST
          done < $LOGDIR/$F_LIST
		rm $LOGDIR/$F_LIST
        else
          echo "$S_FILE  $S_DIR  $S_HOST  $S_ACT  $S_PWD  $CHCK_TYPE  $T_NAME  $T_DIR  $T_HOST  $T_ACT  $T_PWD  $MAIL_TO  $TARGET_TYPE  $NEXTJOB_NAME  $MQ_FILTER  $MQ_NAME  $JOB_ID  $LOCAL_DIR  " >> $LOGDIR/$RUN_LIST 
        fi

   else
      echo "Not RunJob $S_FILE"
   fi
fi
done < $FILELIST   

 
# '(' and ')'  translate
sed -i -e 's/(/\\\(/gi' $LOGDIR/$RUN_LIST
sed -i -e 's/)/\\\)/gi' $LOGDIR/$RUN_LIST


touch $LOGDIR/$RUN_LIST >&2
chmod 777 $LOGDIR/$RUN_LIST >&2 
#Passing List to DSJob
#ResetJob
#RunJob
#echo dsjob -run -warn 0 -mode NORMAL -param runlist=$RUN_LIST -jobstatus $PROJECT $JOBNAME >&2
fi
else
echo "Datastage Engine is not running "
fi

