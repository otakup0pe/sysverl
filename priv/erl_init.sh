#!/usr/bin/env bash

usage() {
    echo "Usage: $0 {start|stop|restart|shell|rescue|hotload|status}"
}

service_pids() {
    SERVICE_PID=`ps ax | grep -e 'name $NODENAME' | grep heart | grep -v grep | cut -f 1 -d ' '`
    if [ "$SERVICE_PID" != "" ] ; then
        HEART_PID=`ps ax | grep "heart -pid $SERVICE_PID"`
    fi
    echo "$SERVICE_PID $HEART_PID"
}

real_start() {
    export HEART_COMMAND="$ROOTDIR/bin/{{erlinit_component}} start $*"
    umask 002
    $ERL \
        -name $NODENAME@$HOSTNAME \
        -args_file $ROOTDIR/config/vm.args \
        -noshell \
        -noinput \
        ${SMPOPTIONS} \
        -config $ROOTDIR/config/{{erlinit_component}} \
        -boot $ROOTDIR/releases/$APP_VSN/{{erlinit_component}} \
        -heart \
        -detached \
        $*
}

start() {
    if [ ! -f $RUNDIR/seppuku ] ; then
        real_start $*
    fi
}

pid_there() {
    PID="$1"
    if [ "$PID1" == "" ] ; then
        echo 0
    else
        if [ `ps $PID | wc -l` -gt 1 ] ; then
            echo 1
        else
            echo 0
        fi
    fi
}

force_stop() {
    if [ $STOP_COUNTER == 0 ] ; then
        echo "unable to stop $NODENAME"
        exit 1
    fi
    PIDS=`service_pids`
    PID1=`echo $PIDS | cut -f 1 -d ' '`
    PID2=`echo $PIDS | cut -f 2 -d ' '`
    OK=1
    if [ `pid_there $PID1` == 1 ] ; then
        kill $PID1
        OK=0
    fi
    if [ `pid_there $PID2` == 1 ] ; then
        kill $PID2
        OK=0
    fi
    if [ $OK == 0 ] ; then
        sleep 1s;
        STOP_COUNTER=`expr $STOP_COUNTER - 1`
        force_stop
    fi
}

stop() {
    touch $RUNDIR/seppuku
    $ERL \
        -args_file $ROOTDIR/config/vm-clean.args \
        -name ${NODENAME}_ctl@$HOSTNAME \
        -hidden \
        -noinput \
        -noshell \
        -s erlinit_ctl stop $NODENAME@$HOSTNAME -s init stop -hidden \
        -config $ROOTDIR/config/{{erlinit_component}} \
        -boot $ROOTDIR/releases/start_clean
    STOP_COUNTER=10
    force_stop
    rm -f $RUNDIR/seppuku
    exit 0
}

shell() {
    echo "Connecting to $NODENAME...."
    LENAME="$NODENAME_console${RANDOM}"
    $ERL \
        -args_file $ROOTDIR/config/vm-clean.args \
        -name $LENAME@$HOSTNAME \
        -remsh $NODENAME@$HOSTNAME \
        -hidden \
        -config $ROOTDIR/config/shell \
        -boot $ROOTDIR/releases/start_clean \
        $*
}

rescue() {
    umask 002
    $ERL \
        -name $NODENAME@$HOSTNAME \
        -args_file $ROOTDIR/config/vm.args \
	    -config $ROOTDIR/config/{{erlinit_component}} \
        -boot $ROOTDIR/releases/$APP_VSN/{{erlinit_component}} \
        $*
}

hotload() {
    $ERL \
        -args_file $ROOTDIR/config/vm-clean.args \
        -name ${NODENAME}_ctl@$HOSTNAME \
        -noshell \
        -hidden \
        -s erlinit_ctl hotload $NODENAME@$HOSTNAME \
        -s init stop \
        -config $ROOTDIR/config/shell \
        -boot $ROOTDIR/releases/start_clean
}

status() {
    $ERL \
        -args_file $ROOTDIR/config/vm-clean.args \
        -name ${NODENAME}_ctl@$HOSTNAME \
        -noshell \
        -hidden \
        -s erlinit_ctl status $NODENAME@$HOSTNAME \
        -s init stop \
        -config $ROOTDIR/config/shell \
        -boot $ROOTDIR/releases/start_clean
    if [ "$?" == "0" ] ; then
        echo "OK: $NODENAME is alive and hopefully well"
    else
        echo "CRITICAL: $NODENAME is not responding"
    fi
}

if [ -L $0 ] ; then
    SELF=$(readlink $0)
else
    SELF=$0
fi

INIT_SCRIPT_DIR=$(cd ${SELF%/*} && pwd)
ROOTDIR=${INIT_SCRIPT_DIR%/*}
RUNDIR=$ROOTDIR

if [ $# -eq 0 ] ; then
    usage
    exit 1
fi


HOSTNAME=$(hostname -f)

if [ "$(id -u)" == "0" ]; then
    echo "Service should not be run as root." 1>&2
    exit
fi

START_ERL=`cat $ROOTDIR/releases/start_erl.data`
ERTS_VSN=${START_ERL% *}
APP_VSN=${START_ERL#* }

if [ $# -lt 1 ] ; then
    usage
    exit 1
fi

export ERL_INETRC=$ROOTDIR/config/inetrc

DDIR=$(pwd)
cd $ROOTDIR
CMD="$1"

if [ "$#" == 2 ] ; then
    NODENAME="${2}_{{erlinit_component}}"
else
    NODENAME={{erlinit_component}}
fi

if [ -e /etc/default/{{erlinit_component}} ] ; then
    . /etc/default/{{erlinit_component}}
fi

if [ "$(which erl)" == "" ] ; then
    ERL="${ROOTDIR}/bin/erl"
else
    ERL="$(which erl)"
fi

for d in $(ls $ROOTDIR/lib) ; do
    ERL_LIBS="$ERL_LIBS$ROOTDIR/lib/$d/:"
done
ERL_LIBS=${ERL_LIBS:0:$(expr ${#ERL_LIBS} - 1)}
export ERL_LIBS=$ERL_LIBS

shift ; shift
case "$CMD" in
    start)
        start $*
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        start
        ;;
    rs_start)
        rs_start
        ;;
    shell)
        shell
        ;;
    rescue)
        rescue $*
        ;;
    hotload)
        hotload
        ;;
    status)
        status
        ;;
    *)
        usage
        cd $DDIR
        exit 1
esac

cd $DDIR

exit 0
