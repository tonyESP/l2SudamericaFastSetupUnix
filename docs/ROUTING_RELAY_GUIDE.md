# GUÍA DE INGENIERÍA: RELAY DE BAJA LATENCIA (ESPAÑA ⟷ BRASIL ⟷ BUENOS AIRES)

Esta guía detalla el despliegue del túnel WireGuard en modo **Split-Tunneling** para reducir la latencia de Lineage 2 desde España hacia el GameServer (`45.235.99.29`) en Buenos Aires (Argentina), pasando de **~262 ms** a **~150-170 ms**.

---

## 1. PRINCIPIO DE AISLAMIENTO (CERO RIESGOS)

- **Split-Tunneling estricto**: La configuración (`AllowedIPs = 45.235.99.29/32, 10.66.66.1/32`) **SOLO** enruta los paquetes dirigidos al servidor de L2 a través del túnel.
- Tu navegador web, Discord, Steam, descargas y el resto del sistema **siguen funcionando 100% por tu fibra de casa**.
- **Rollback instantáneo**: Si el VPS se apaga o bajas el túnel con `./scripts/relay_ctl.sh down`, el juego vuelve a usar inmediatamente la conexión directa de tu ISP sin tocar ningún archivo del juego ni requerir reinicios.

---

## 2. PASO 1: CONSEGUIR EL VPS EN SÃO PAULO (BRASIL)

Cualquiera de estas opciones sirve (se recomienda São Paulo para tomar la ruta de baja latencia):

### Opción A (Gratis de por vida): Oracle Cloud Free Tier
1. Crea una cuenta en [Oracle Cloud](https://www.oracle.com/cloud/free/).
2. Al elegir tu *Home Region*, selecciona **South America East (São Paulo)** / `sa-saopaulo-1`.
3. Crea una instancia de computación gratuita (*Always Free Eligible*):
   - Imagen: **Ubuntu 22.04 / 24.04**.
   - Asigna una IP pública IPv4.
4. En la consola web de Oracle (VCN / Security Lists):
   - Abre el puerto **UDP 51820** en las reglas de entrada (*Ingress Rules*).

### Opción B (Prueba rápida por horas): AWS Lightsail o Linode
1. En **AWS Lightsail**, crea una instancia de $3.50/mes seleccionando la región **São Paulo (sa-east-1)**.
2. Abre el puerto **UDP 51820** en el cortafuegos de Lightsail.
3. Se factura por horas (~0,005 $/hora); si no te convence, la eliminas y solo pagas céntimos.

---

## 3. PASO 2: DESPLEGAR EL RELAY EN EL VPS (UN SOLO COMANDO)

Conéctate por SSH a tu VPS en São Paulo:

```bash
ssh ubuntu@<IP_PUBLICA_DEL_VPS>
```

Y ejecuta el aprovisionamiento automatizado incluido en el proyecto:

```bash
curl -sSL https://raw.githubusercontent.com/.../tools/relay/setup_vps.sh | sudo bash
# O copiando el script localmente:
scp /mnt/disk4u/L2/tools/relay/setup_vps.sh ubuntu@<IP_PUBLICA_DEL_VPS>:~/
ssh ubuntu@<IP_PUBLICA_DEL_VPS> "sudo ./setup_vps.sh"
```

El script:
- Instala WireGuard e iptables.
- Activa el algoritmo BBR y el reenvío de paquetes IP en el kernel.
- Genera las claves criptográficas.
- Muestra en pantalla el archivo `wg-l2suda.conf` listo para el cliente.

---

## 4. PASO 3: CONFIGURAR TU PORTÁTIL EN LINUX

1. Instala las herramientas de WireGuard en tu portátil (si no las tienes):
   ```bash
   sudo apt install -y wireguard-tools
   ```
2. Guarda la configuración que te dio el script en el archivo:
   ```bash
   /mnt/disk4u/L2/config/relay/wg-l2suda.conf
   ```
   *(Asegúrate de que tenga permisos seguros: `chmod 600 /mnt/disk4u/L2/config/relay/wg-l2suda.conf`)*.

---

## 5. PASO 4: CONTROL Y OPERACIÓN DIARIA

En tu portátil dispones del script de gestión:

```bash
# 1. Comprobar salud del entorno
./scripts/relay_ctl.sh doctor

# 2. Medir ping al VPS antes de activar
./scripts/relay_ctl.sh test <IP_DEL_VPS>

# 3. Levantar el túnel optimizado
./scripts/relay_ctl.sh up

# 4. Ver estado de la ruta y ping activo
./scripts/relay_ctl.sh status

# 5. Volver a la ruta directa de tu ISP (desactivar túnel)
./scripts/relay_ctl.sh down
```

---

## 6. PROTOCOLO DE DESHACER (ROLLBACK TOTAL)

Si por cualquier motivo la conexión a Brasil tiene problemas o el VPS está caído:
1. Ejecuta:
   ```bash
   ./scripts/relay_ctl.sh down
   ```
2. O simplemente lanza el juego como siempre:
   ```bash
   ./scripts/l2_ctl.sh run l2suda-optimizado
   ```
   El juego conectará directamente a través de tu proveedor de internet habitual con los 262 ms de siempre.
