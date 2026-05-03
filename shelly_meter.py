#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Shelly EM/3EM Meter para Victron Venus OS
Soporta Shelly EM (monofásico) y Shelly 3EM (trifásico)
"""

import sys
import os
import json
import requests
import time
from requests.auth import HTTPBasicAuth

# Victron packages
sys.path.insert(1, os.path.join(os.path.dirname(__file__), '/opt/victronenergy/dbus-systemcalc-py/ext/velib_python'))
from vedbus import VeDbusService
from settingsdevice import SettingsDevice

class ShellyMeter:
    def __init__(self, config):
        self.config = config
        self.ip = config['ip']
        self.device_type = config.get('device_type', 'em')  # 'em' o '3em'
        self.clamp = config.get('clamp', 0)  # Para Shelly EM: 0 o 1
        self.username = config.get('username', None)
        self.password = config.get('password', None)
        self.poll_interval = config.get('poll_interval', 2000)  # ms
        self.servicename = config.get('servicename', 'com.victronenergy.grid')
        self.deviceinstance = config.get('deviceinstance', 40)
        self.customname = config.get('customname', 'Shelly Meter')
        self.invert_power = config.get('invert_power', False)
        self.position = config.get('position', 0)
        self.role = config.get('role', 'grid')
        
        self._dbusservice = None
        self._last_update = 0
        
        # Validar configuración
        if self.device_type not in ['em', '3em']:
            raise ValueError("device_type debe ser 'em' o '3em'")
        
        if self.device_type == 'em' and self.clamp not in [0, 1]:
            raise ValueError("Para Shelly EM, clamp debe ser 0 o 1")
        
    def setup_dbus(self):
        """Configura el servicio D-Bus"""
        self._dbusservice = VeDbusService(
            f"{self.servicename}.http_{self.deviceinstance}",
            bus=self._get_dbus()
        )
        
        # Información del dispositivo
        device_name = "Shelly 3EM" if self.device_type == '3em' else "Shelly EM"
        self._dbusservice.add_path('/Mgmt/ProcessName', __file__)
        self._dbusservice.add_path('/Mgmt/ProcessVersion', '2.1')
        self._dbusservice.add_path('/Mgmt/Connection', f'{device_name} at {self.ip}')
        self._dbusservice.add_path('/DeviceInstance', self.deviceinstance)
        self._dbusservice.add_path('/ProductId', 0)
        self._dbusservice.add_path('/ProductName', f'{device_name} Meter')
        self._dbusservice.add_path('/FirmwareVersion', '2.1')
        self._dbusservice.add_path('/HardwareVersion', device_name)
        self._dbusservice.add_path('/Connected', 1)
        self._dbusservice.add_path('/CustomName', self.customname)
        self._dbusservice.add_path('/Position', self.position)
        self._dbusservice.add_path('/Role', self.role)
        
        # Paths comunes (totales)
        self._dbusservice.add_path('/Ac/Power', None, gettextcallback=lambda p, v: f"{v}W")
        self._dbusservice.add_path('/Ac/Current', None, gettextcallback=lambda p, v: f"{v}A")
        self._dbusservice.add_path('/Ac/Voltage', None, gettextcallback=lambda p, v: f"{v}V")
        self._dbusservice.add_path('/Ac/Energy/Forward', None, gettextcallback=lambda p, v: f"{v}kWh")
        self._dbusservice.add_path('/Ac/Energy/Reverse', None, gettextcallback=lambda p, v: f"{v}kWh")
        
        # Paths por fase - CRÍTICO: solo crear las fases necesarias
        # Shelly EM (monofásico): solo L1
        # Shelly 3EM (trifásico): L1, L2, L3
        if self.device_type == 'em':
            phases_to_create = ['L1']
        else:
            phases_to_create = ['L1', 'L2', 'L3']
        
        for phase in phases_to_create:
            self._dbusservice.add_path(f'/Ac/{phase}/Power', None, gettextcallback=lambda p, v: f"{v}W")
            self._dbusservice.add_path(f'/Ac/{phase}/Current', None, gettextcallback=lambda p, v: f"{v}A")
            self._dbusservice.add_path(f'/Ac/{phase}/Voltage', None, gettextcallback=lambda p, v: f"{v}V")
            self._dbusservice.add_path(f'/Ac/{phase}/Energy/Forward', None, gettextcallback=lambda p, v: f"{v}kWh")
            self._dbusservice.add_path(f'/Ac/{phase}/Energy/Reverse', None, gettextcallback=lambda p, v: f"{v}kWh")
            self._dbusservice.add_path(f'/Ac/{phase}/PowerFactor', None)
        
        phase_info = "monofásico (solo L1)" if self.device_type == 'em' else "trifásico (L1, L2, L3)"
        print(f"D-Bus service configurado: {self.servicename}.http_{self.deviceinstance} - {phase_info}")
        
    def _get_dbus(self):
        """Obtiene la conexión D-Bus correcta"""
        import dbus
        return dbus.SystemBus() if (platform.machine() == 'armv7l') else dbus.SessionBus()
    
    def fetch_data(self):
        """Obtiene los datos del Shelly"""
        try:
            url = f"http://{self.ip}/status"
            
            if self.username and self.password:
                response = requests.get(
                    url, 
                    auth=HTTPBasicAuth(self.username, self.password),
                    timeout=5
                )
            else:
                response = requests.get(url, timeout=5)
            
            if response.status_code == 200:
                data = response.json()
                return self.parse_data(data)
            else:
                print(f"Error HTTP: {response.status_code}")
                return None
                
        except requests.exceptions.RequestException as e:
            print(f"Error al conectar con Shelly: {e}")
            self._dbusservice['/Connected'] = 0
            return None
    
    def parse_data(self, data):
        """Procesa los datos según el tipo de dispositivo"""
        if self.device_type == 'em':
            return self._parse_shelly_em(data)
        else:
            return self._parse_shelly_3em(data)
    
    def _parse_shelly_em(self, data):
        """Procesa datos del Shelly EM (monofásico, 2 pinzas)"""
        try:
            if 'emeters' not in data or len(data['emeters']) <= self.clamp:
                print(f"Error: No se encontró la pinza {self.clamp} en los datos")
                return None
            
            emeter = data['emeters'][self.clamp]
            
            if not emeter.get('is_valid', False):
                print(f"Advertencia: Los datos de la pinza {self.clamp} no son válidos")
            
            # Extraer datos
            power = emeter.get('power', 0)
            
            if self.invert_power:
                power = -power
            
            voltage = emeter.get('voltage', 0)
            pf = emeter.get('pf', 0)
            total = emeter.get('total', 0) / 1000
            total_returned = emeter.get('total_returned', 0) / 1000
            
            # Calcular corriente
            current = power / abs(voltage) if voltage != 0 else 0
            
            parsed_data = {
                'total_power': round(power, 2),
                'total_current': round(current, 2),
                'total_voltage': round(abs(voltage), 2),
                'total_energy_forward': round(total, 3),
                'total_energy_reverse': round(total_returned, 3),
                'phases': {
                    'L1': {
                        'power': round(power, 2),
                        'current': round(current, 2),
                        'voltage': round(abs(voltage), 2),
                        'pf': round(pf, 2),
                        'energy_forward': round(total, 3),
                        'energy_reverse': round(total_returned, 3)
                    },
                    'L2': {
                        'power': 0,
                        'current': 0,
                        'voltage': 0,
                        'pf': 0,
                        'energy_forward': 0,
                        'energy_reverse': 0
                    },
                    'L3': {
                        'power': 0,
                        'current': 0,
                        'voltage': 0,
                        'pf': 0,
                        'energy_forward': 0,
                        'energy_reverse': 0
                    }
                }
            }
            
            return parsed_data
            
        except Exception as e:
            print(f"Error al procesar datos Shelly EM: {e}")
            return None
    
    def _parse_shelly_3em(self, data):
        """Procesa datos del Shelly 3EM (trifásico)"""
        try:
            if 'emeters' not in data or len(data['emeters']) < 3:
                print("Error: No se encontraron las 3 fases en los datos")
                return None
            
            # Extraer datos de las 3 fases
            phases_data = {}
            total_power = 0
            total_current = 0
            total_voltage = 0
            total_energy_forward = 0
            total_energy_reverse = 0
            
            phase_names = ['L1', 'L2', 'L3']
            
            for i, phase_name in enumerate(phase_names):
                emeter = data['emeters'][i]
                
                if not emeter.get('is_valid', False):
                    print(f"Advertencia: Los datos de la fase {phase_name} no son válidos")
                
                power = emeter.get('power', 0)
                
                # Invertir todas las fases si está configurado
                if self.invert_power:
                    power = -power
                
                voltage = emeter.get('voltage', 0)
                pf = emeter.get('pf', 0)
                total = emeter.get('total', 0) / 1000
                total_ret = emeter.get('total_returned', 0) / 1000
                
                # Calcular corriente
                current = power / abs(voltage) if voltage != 0 else 0
                
                phases_data[phase_name] = {
                    'power': round(power, 2),
                    'current': round(current, 2),
                    'voltage': round(abs(voltage), 2),
                    'pf': round(pf, 2),
                    'energy_forward': round(total, 3),
                    'energy_reverse': round(total_ret, 3)
                }
                
                # Sumar totales
                total_power += power
                total_current += abs(current)
                total_voltage += abs(voltage)
                total_energy_forward += total
                total_energy_reverse += total_ret
            
            # Calcular voltaje promedio
            avg_voltage = total_voltage / 3 if total_voltage > 0 else 0
            
            parsed_data = {
                'total_power': round(total_power, 2),
                'total_current': round(total_current, 2),
                'total_voltage': round(avg_voltage, 2),
                'total_energy_forward': round(total_energy_forward, 3),
                'total_energy_reverse': round(total_energy_reverse, 3),
                'phases': phases_data
            }
            
            return parsed_data
            
        except Exception as e:
            print(f"Error al procesar datos Shelly 3EM: {e}")
            return None
    
    def update_dbus(self, data):
        """Actualiza los valores en D-Bus"""
        if data is None:
            return
        
        try:
            # Actualizar valores totales
            self._dbusservice['/Ac/Power'] = data['total_power']
            self._dbusservice['/Ac/Current'] = data['total_current']
            self._dbusservice['/Ac/Voltage'] = data['total_voltage']
            self._dbusservice['/Ac/Energy/Forward'] = data['total_energy_forward']
            self._dbusservice['/Ac/Energy/Reverse'] = data['total_energy_reverse']
            
            # Actualizar valores por fase - SOLO las fases que se crearon en setup_dbus
            for phase_name, phase_data in data['phases'].items():
                # Verificar que el path existe antes de actualizarlo
                path_power = f'/Ac/{phase_name}/Power'
                if path_power in self._dbusservice:
                    self._dbusservice[path_power] = phase_data['power']
                    self._dbusservice[f'/Ac/{phase_name}/Current'] = phase_data['current']
                    self._dbusservice[f'/Ac/{phase_name}/Voltage'] = phase_data['voltage']
                    self._dbusservice[f'/Ac/{phase_name}/Energy/Forward'] = phase_data['energy_forward']
                    self._dbusservice[f'/Ac/{phase_name}/Energy/Reverse'] = phase_data['energy_reverse']
                    self._dbusservice[f'/Ac/{phase_name}/PowerFactor'] = phase_data['pf']
            
            self._dbusservice['/Connected'] = 1
            
            if self.device_type == '3em':
                print(f"Datos actualizados - Total: {data['total_power']}W | " +
                      f"L1: {data['phases']['L1']['power']}W | " +
                      f"L2: {data['phases']['L2']['power']}W | " +
                      f"L3: {data['phases']['L3']['power']}W")
            else:
                print(f"Datos actualizados - Power: {data['total_power']}W, " +
                      f"Voltage: {data['total_voltage']}V, " +
                      f"Current: {data['total_current']}A")
            
        except Exception as e:
            print(f"Error al actualizar D-Bus: {e}")
    
    def run(self):
        """Bucle principal"""
        from dbus.mainloop.glib import DBusGMainLoop
        from gi.repository import GLib
        
        DBusGMainLoop(set_as_default=True)
        
        self.setup_dbus()
        
        def update_callback():
            data = self.fetch_data()
            self.update_dbus(data)
            return True
        
        # Primera actualización inmediata
        update_callback()
        
        # Configurar actualización periódica
        GLib.timeout_add(self.poll_interval, update_callback)
        
        device_info = f"Shelly {self.device_type.upper()}"
        if self.device_type == 'em':
            device_info += f" - Pinza {self.clamp}"
        
        print(f"{device_info} Meter iniciado - IP: {self.ip}")
        print(f"Intervalo de actualización: {self.poll_interval}ms")
        
        mainloop = GLib.MainLoop()
        mainloop.run()


def load_config(config_file):
    """Carga la configuración desde un archivo JSON"""
    try:
        with open(config_file, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"Error al cargar configuración: {e}")
        sys.exit(1)


if __name__ == "__main__":
    import platform
    
    if len(sys.argv) < 2:
        print("Uso: python shelly_meter.py <config.json>")
        sys.exit(1)
    
    config_file = sys.argv[1]
    config = load_config(config_file)
    
    meter = ShellyMeter(config)
    meter.run()
