#!/bin/bash
set -euo pipefail

clear
echo "============================================"
echo "     BOT TELEGRAM - CONTROL DE VPS         "
echo "============================================"
echo ""

if [ -f /etc/bot-vps/config.env ]; then
  source /etc/bot-vps/config.env
else
  read -p "Ingresa el TOKEN de tu Bot: " TOKEN
  read -p "Ingresa tu ID de Telegram: " ADMIN_ID
  mkdir -p /etc/bot-vps
  cat > /etc/bot-vps/config.env << 'EOF'
TOKEN="$TOKEN"
ADMIN_ID=ADMIN_ID
EOF
  sed -i "s/TOKEN=\"\$TOKEN\"/TOKEN=\"$TOKEN\"/" /etc/bot-vps/config.env
  sed -i "s/ADMIN_ID=ADMIN_ID/ADMIN_ID=$ADMIN_ID/" /etc/bot-vps/config.env
fi

echo ""
echo "📦 Instalando dependencias..."
apt update -y >/dev/null 2>&1
apt install -y python3 python3-pip vnstat speedtest-cli >/dev/null 2>&1

echo "📦 Instalando librerías..."
pip3 install python-telegram-bot==13.7 psutil --break-system-packages >/dev/null 2>&1

mkdir -p /etc/bot-vps
cd /etc/bot-vps || exit

cat > bot.py << 'PYTHON_EOF'
from telegram import Update, ReplyKeyboardMarkup
from telegram.ext import Updater, CommandHandler, MessageHandler, Filters, CallbackContext
import subprocess, os, time, psutil, datetime
from config import TOKEN, ADMIN_ID

def is_admin(uid): return uid == ADMIN_ID

def barra_porcentaje(porcentaje, largo=10):
    lleno = int(porcentaje * largo / 100)
    return "■" * lleno + "□" * (largo - lleno)

def obtener_datos_sistema():
    cpu = psutil.cpu_percent(interval=0.5)
    nucleos = psutil.cpu_count()
    ram_total = round(psutil.virtual_memory().total / (1024*1024))
    ram_usada = round(psutil.virtual_memory().used / (1024*1024))
    ram_porcentaje = round(ram_usada * 100 / ram_total, 1)
    disco_total = round(psutil.disk_usage('/').total / (1024*1024*1024))
    disco_usado = round(psutil.disk_usage('/').used / (1024*1024*1024))
    disco_porcentaje = round(disco_usado * 100 / disco_total, 1)
    encendido = time.time() - psutil.boot_time()
    horas = int(encendido // 3600)
    minutos = int((encendido % 3600) // 60)
    uptime = f"{horas}h, {minutos}m"
    return cpu, nucleos, ram_usada, ram_total, ram_porcentaje, disco_usado, disco_total, disco_porcentaje, uptime

def start(update: Update, context: CallbackContext):
    if not is_admin(update.effective_user.id):
        update.message.reply_text("⛔ ACCESO DENEGADO ⛔")
        return

    cpu, nucleos, ram_usada, ram_total, ram_porcentaje, disco_usado, disco_total, disco_porcentaje, uptime = obtener_datos_sistema()

    mensaje = f"""
💻 BOT MAQUINA AWS-VPS V8.0.5 (VPS HTTP)
Panel de Control Avanzado
👤 CREADOR: AWS Cloud

🧠 CPU: [{barra_porcentaje(cpu)}] {round(cpu,1)}% ({nucleos} Cores)
💾 RAM: [{barra_porcentaje(ram_porcentaje)}] {ram_usada}MB / {ram_total}MB
💽 DISCO: [{barra_porcentaje(disco_porcentaje)}] {disco_usado}GB / {disco_total}GB
⏱️ Uptime: {uptime}
"""

    teclado = [
        ["👤 Crear Usuario", "📋 Ver Usuarios"],
        ["🔐 Cambiar Clave", "🔄 Renovar Usuario"],
        ["🚫 Bloquear", "✅ Desbloquear"],
        ["🗑️ Eliminar Usuario", "📊 Estado VPS"],
        ["📈 Consumo GB", "⚡ Velocidad"],
        ["📝 Conexiones", "⚙️ Comando"],
        ["🔄 Reiniciar", "📤 Apagar"]
    ]
    markup = ReplyKeyboardMarkup(teclado, resize_keyboard=True)
    update.message.reply_text(mensaje, reply_markup=markup)

def mensaje(update: Update, context: CallbackContext):
    texto = update.message.text
    uid = update.effective_user.id
    if not is_admin(uid): return

    paso = context.user_data.get("paso", "")

    if texto == "👤 Crear Usuario":
        update.message.reply_text("✏️ NOMBRE DEL USUARIO:")
        context.user_data["paso"] = "crear_nombre"

    elif texto == "📋 Ver Usuarios":
        usuarios = subprocess.getoutput("cat /etc/passwd | grep /home | grep -v nologin")
        update.message.reply_text(f"📋 LISTA DE USUARIOS:\n\n{usuarios[:3500]}")

    elif texto == "🔐 Cambiar Clave":
        update.message.reply_text("✏️ USUARIO:")
        context.user_data["paso"] = "cambiar_nombre"

    elif texto == "🔄 Renovar Usuario":
        update.message.reply_text("✏️ USUARIO A RENOVAR:")
        context.user_data["paso"] = "renovar_nombre"

    elif texto == "🗑️ Eliminar Usuario":
        update.message.reply_text("⚠️ USUARIO A BORRAR:")
        context.user_data["paso"] = "borrar_nombre"

    elif texto == "🚫 Bloquear":
        update.message.reply_text("✏️ USUARIO A BLOQUEAR:")
        context.user_data["paso"] = "bloquear_nombre"

    elif texto == "✅ Desbloquear":
        update.message.reply_text("✏️ USUARIO A ACTIVAR:")
        context.user_data["paso"] = "desbloquear_nombre"

    elif texto == "📊 Estado VPS":
        cpu, nucleos, ram_usada, ram_total, ram_porcentaje, disco_usado, disco_total, disco_porcentaje, uptime = obtener_datos_sistema()
        mensaje = f"""📊 ESTADO DEL SERVIDOR:

🧠 CPU: [{barra_porcentaje(cpu)}] {round(cpu,1)}% ({nucleos} Cores)
💾 RAM: [{barra_porcentaje(ram_porcentaje)}] {ram_usada}MB / {ram_total}MB
💽 DISCO: [{barra_porcentaje(disco_porcentaje)}] {disco_usado}GB / {disco_total}GB
⏱️ Uptime: {uptime}"""
        update.message.reply_text(mensaje)

    elif texto == "📈 Consumo GB":
        consumo = subprocess.getoutput("vnstat -d")
        update.message.reply_text(f"📈 CONSUMO DE INTERNET:\n\n{consumo[:3500]}")

    elif texto == "⚡ Velocidad":
        velocidad = subprocess.getoutput("speedtest-cli --simple")
        update.message.reply_text(f"⚡ VELOCIDAD DE CONEXIÓN:\n\n{velocidad[:3500]}")

    elif texto == "📝 Conexiones":
        conexiones = subprocess.getoutput("last -a | head -20")
        update.message.reply_text(f"📝 ÚLTIMAS CONEXIONES:\n\n{conexiones[:3500]}")

    elif texto == "⚙️ Comando":
        update.message.reply_text("✏️ ESCRIBE EL COMANDO:")
        context.user_data["paso"] = "comando"

    elif texto == "🔄 Reiniciar":
        update.message.reply_text("🔄 REINICIANDO...")
        os.system("reboot")

    elif texto == "📤 Apagar":
        update.message.reply_text("📤 APAGANDO...")
        os.system("poweroff")

    elif paso == "crear_nombre":
        nombre = texto.replace(" ", "_")
        os.system(f"useradd -m -s /bin/bash {nombre}")
        os.system(f"echo '{nombre}:Abc12345*' | chpasswd")
        update.message.reply_text(f"""✅ USUARIO CREADO:

👤 USUARIO: {nombre}
🔑 CLAVE: Abc12345*""")
        context.user_data["paso"] = ""

    elif paso == "cambiar_nombre":
        context.user_data["usuario_cambiar"] = texto
        update.message.reply_text(f"✏️ NUEVA CONTRASEÑA PARA {texto}:")
        context.user_data["paso"] = "cambiar_clave"

    elif paso == "cambiar_clave":
        nombre = context.user_data["usuario_cambiar"]
        clave = texto
        os.system(f"echo '{nombre}:{clave}' | chpasswd")
        update.message.reply_text(f"✅ CONTRASEÑA CAMBIADA:\n👤 {nombre}\n🔑 {clave}")
        context.user_data["paso"] = ""

    elif paso == "renovar_nombre":
        context.user_data["usuario_renovar"] = texto
        update.message.reply_text(f"✏️ CANTIDAD DE DÍAS PARA {texto} (ej: 30):")
        context.user_data["paso"] = "renovar_dias"

    elif paso == "renovar_dias":
        nombre = context.user_data["usuario_renovar"]
        dias = int(texto)
        fecha_fin = (datetime.datetime.now() + datetime.timedelta(days=dias)).strftime("%Y-%m-%d")
        os.system(f"chage -E {fecha_fin} {nombre}")
        update.message.reply_text(f"✅ USUARIO RENOVADO:\n👤 {nombre}\n📅 VENCE: {fecha_fin}")
        context.user_data["paso"] = ""

    elif paso == "borrar_nombre":
        nombre = texto.replace(" ", "_")
        os.system(f"userdel -r {nombre} 2>/dev/null")
        update.message.reply_text(f"✅ USUARIO {nombre} ELIMINADO")
        context.user_data["paso"] = ""

    elif paso == "bloquear_nombre":
        nombre = texto.replace(" ", "_")
        os.system(f"usermod -L {nombre}")
        update.message.reply_text(f"🚫 USUARIO {nombre} BLOQUEADO")
        context.user_data["paso"] = ""

    elif paso == "desbloquear_nombre":
        nombre = texto.replace(" ", "_")
        os.system(f"usermod -U {nombre}")
        update.message.reply_text(f"✅ USUARIO {nombre} DESBLOQUEADO")
        context.user_data["paso"] = ""

    elif paso == "comando":
        resultado = subprocess.getoutput(f"{texto}")
        update.message.reply_text(f"⚙️ RESULTADO:\n\n{resultado[:3500]}")
        context.user_data["paso"] = ""

def main():
    try:
        updater = Updater(TOKEN, use_context=True)
        dp = updater.dispatcher
        dp.add_handler(CommandHandler("start", start))
        dp.add_handler(MessageHandler(Filters.text & ~Filters.command, mensaje))
        updater.start_polling()
        print("✅ BOT ACTIVO")
        updater.idle()
    except Exception as e:
        print(f"ERROR: {e}")

if __name__ == "__main__":
    main()
PYTHON_EOF

cat > config.py << 'EOF'
import os
TOKEN = os.environ.get("TOKEN", "")
ADMIN_ID = int(os.environ.get("ADMIN_ID", "0"))
EOF

cat > /etc/systemd/system/bot-vps.service << 'EOF'
[Unit]
Description=Panel AWS-VPS
After=network.target

[Service]
WorkingDirectory=/etc/bot-vps
Environment="TOKEN="
Environment="ADMIN_ID="
ExecStart=/usr/bin/python3 /etc/bot-vps/bot.py
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

sed -i "s/Environment=\"TOKEN=\"/Environment=\"TOKEN=$TOKEN\"/" /etc/systemd/system/bot-vps.service
sed -i "s/Environment=\"ADMIN_ID=\"/Environment=\"ADMIN_ID=$ADMIN_ID\"/" /etc/systemd/system/bot-vps.service

systemctl daemon-reload >/dev/null 2>&1
systemctl enable bot-vps >/dev/null 2>&1
systemctl restart bot-vps

echo ""
echo "✅ TODO LISTO!"
echo "Escribe /start en tu bot de Telegram"
EOF
