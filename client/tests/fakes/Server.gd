extends Reference

# Keeps what Match would send to the server

var sent = []

func ws_send_message(message):
    sent.append(message)
