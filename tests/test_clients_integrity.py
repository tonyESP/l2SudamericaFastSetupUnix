"""
Test de Integración y Verificación Física de Clientes L2.
Directiva Suprema: 0 Complacencia, 0 Sesgo, 0 Espejo.
Verifica que los 3 clientes de Lineage 2 estén físicamente extraídos,
con cabeceras PE32 auténticas, estructura de directorios íntegra
y archivos de fine-tuning (DXVK / Option.ini) debidamente inyectados.
"""

import json
import os
import struct
import unittest

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SERVERS_JSON = os.path.join(PROJECT_ROOT, "config", "servers.json")
CLIENTS_DIR = os.path.join(PROJECT_ROOT, "clients")


class TestClientsIntegrity(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        with open(SERVERS_JSON, "r", encoding="utf-8") as f:
            data = json.load(f)
        cls.servers = data["servers"]

    def test_all_client_folders_exist(self) -> None:
        """Verifica que el directorio de staging de cada servidor exista en disk."""
        for s_id in self.servers:
            client_path = os.path.join(CLIENTS_DIR, s_id)
            self.assertTrue(
                os.path.isdir(client_path),
                f"Directorio de cliente ausente: {client_path}"
            )

    def test_executables_exist_and_executable(self) -> None:
        """Verifica que system/L2.exe o system/l2.exe exista en cada cliente."""
        for s_id in self.servers:
            system_dir = os.path.join(CLIENTS_DIR, s_id, "system")
            self.assertTrue(os.path.isdir(system_dir), f"system/ ausente en {s_id}")

            exe_upper = os.path.join(system_dir, "L2.exe")
            exe_lower = os.path.join(system_dir, "l2.exe")
            has_exe = os.path.isfile(exe_upper) or os.path.isfile(exe_lower)

            self.assertTrue(has_exe, f"No se encontró binario L2.exe/l2.exe en {system_dir}")

    def test_executable_pe32_headers(self) -> None:
        """
        Inspecciona el formato binario PE32 (MZ dos header y firma PE)
        garantizando que no sean archivos stub corruptos.
        """
        for s_id in self.servers:
            system_dir = os.path.join(CLIENTS_DIR, s_id, "system")
            exe_path = os.path.join(system_dir, "L2.exe")
            if not os.path.isfile(exe_path):
                exe_path = os.path.join(system_dir, "l2.exe")

            self.assertTrue(os.path.isfile(exe_path), f"Binario no encontrado en {s_id}")
            self.assertGreater(os.path.getsize(exe_path), 200_000, f"Tamaño sospechosamente pequeño para {exe_path}")

            with open(exe_path, "rb") as f:
                dos_magic = f.read(2)
                self.assertEqual(dos_magic, b"MZ", f"Firma DOS inválida en {exe_path}")

                # Offset to PE header at 0x3C (e_lfanew)
                f.seek(0x3C)
                pe_offset_bytes = f.read(4)
                self.assertEqual(len(pe_offset_bytes), 4, f"Truncated DOS header en {exe_path}")
                pe_offset = struct.unpack("<I", pe_offset_bytes)[0]

                # Check PE signature
                f.seek(pe_offset)
                pe_sig = f.read(4)
                self.assertEqual(pe_sig, b"PE\x00\x00", f"Firma PE inválida en {exe_path}")

                # Check machine type (0x014c for i386 / 32-bit PE)
                machine = struct.unpack("<H", f.read(2))[0]
                self.assertEqual(machine, 0x014C, f"Arquitectura no es i386 (PE32) en {exe_path}: {hex(machine)}")

    def test_essential_asset_trees_exist(self) -> None:
        """Verifica que las carpetas vitales del motor Unreal 2 / 2.5 estén pobladas."""
        for s_id in self.servers:
            client_dir = os.path.join(CLIENTS_DIR, s_id)
            entries = os.listdir(client_dir)
            entries_lower = [e.lower() for e in entries]

            self.assertIn("system", entries_lower, f"system/ ausente en {s_id}")
            self.assertTrue(
                "textures" in entries_lower or "systextures" in entries_lower,
                f"Carpeta de texturas ausente en {s_id}"
            )
            self.assertIn("animations", entries_lower, f"animations/ ausente en {s_id}")

    def test_tuning_files_injected(self) -> None:
        """Verifica que dxvk.conf y Option.ini existan en system/ de cada cliente."""
        for s_id in self.servers:
            system_dir = os.path.join(CLIENTS_DIR, s_id, "system")
            dxvk_path = os.path.join(system_dir, "dxvk.conf")
            option_path = os.path.join(system_dir, "Option.ini")

            self.assertTrue(os.path.isfile(dxvk_path), f"dxvk.conf ausente en {s_id}/system")
            self.assertTrue(os.path.isfile(option_path), f"Option.ini ausente en {s_id}/system")

            with open(dxvk_path, "r", encoding="utf-8") as f:
                content = f.read()
                self.assertIn("d3d9.maxFrameRate", content)
                self.assertIn("d3d9.samplerAnisotropy", content)
                self.assertIn("dxvk.enableAsync", content)

            with open(option_path, "r", encoding="utf-8", errors="ignore") as f:
                opt_content = f.read()
                self.assertIn("[Video]", opt_content)


if __name__ == "__main__":
    unittest.main()
