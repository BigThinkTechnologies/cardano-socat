#!/bin/sh

args="$@"

print_help()
{
	echo "Usage"
   	echo "--socket-file-to-tcp    listen to a source file socket and output to a destination TCP port"
   	echo "--tcp-to-socket-file    to listen to a source TCP port and output to a destination file socket"
   	echo "--help                  show this help"
   	echo ""

   	echo "Environment Variables"		
	echo "when using --socket-file-to-tcp (server mode)"
	echo "SOURCE_SOCKET_PATH"
	echo "DESTINATION_TCP_PORT"

	echo "when using --tcp-to-socket-file (client mode)"
	echo "SOURCE_IP"
	echo "SOURCE_TCP_PORT"
	echo "DESTINATION_SOCKET_PATH"
}

# TODO:// we have to mkdir SOURCE_SOCKET_PATH or DESTINATION_SOCKET_PATH with the last bit left out

# server mode
if [[ "--socket-file-to-tcp" == "$args" ]];
then   	
	if [[ ! -z "$SOURCE_SOCKET_PATH" && "$SOURCE_SOCKET_PATH" != " " && ! -z "$DESTINATION_TCP_PORT" && "$DESTINATION_TCP_PORT" != " " && "${DESTINATION_TCP_PORT##*[!0-9]*}" ]];
	then
		# run in server mode
		mkdir -p "${SOURCE_SOCKET_PATH}/.."
		socat TCP-LISTEN:${DESTINATION_TCP_PORT},fork,reuseaddr, UNIX-CONNECT:${SOURCE_SOCKET_PATH}
	else
		echo "Error, environment variables SOURCE_SOCKET_PATH or DESTINATION_TCP_PORT were not set correctly for socket-file-to-tcp mode"
		print_help
	fi

# client mode
elif [[ "--tcp-to-socket-file" == "$args" ]];
then		
	if [[ ! -z "$DESTINATION_SOCKET_PATH" && "$DESTINATION_SOCKET_PATH" != " " && ! -z "$SOURCE_TCP_PORT" && "$SOURCE_TCP_PORT" != " " && "${SOURCE_TCP_PORT##*[!0-9]*}" && ! -z "$SOURCE_IP" && "SOURCE_IP" != " " ]];
	then
		# run in client model
		mkdir -p "${DESTINATION_SOCKET_PATH}/.."
		socat UNIX-LISTEN:${DESTINATION_SOCKET_PATH},fork,reuseaddr,unlink-early, TCP:${SOURCE_IP}:${SOURCE_TCP_PORT}
	else
		echo "Error, environment variables DESTINATION_SOCKET_PATH or SOURCE_TCP_PORT or SOURCE_IP were not set correctly for tcp-to-socket-file mode"
		print_help
	fi

elif [[ "--help" == "$args" ]];
then
	print_help
else
   echo "Error, no default command argument given"
   print_help
fi

# exec "$@"
