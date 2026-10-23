# Contribuir a Cleaner

Gracias por pasarte por aquí. Cleaner es un proyecto personal, pero las mejoras bien explicadas son bienvenidas: un modo de limpieza nuevo, una salvaguarda para una distro concreta o una corrección en la documentación.

## Antes de empezar

Si el cambio es grande (un modo nuevo, una reestructuración de `config/` o un cambio de comportamiento en la limpieza), abre primero un issue. Así acordamos el enfoque antes de que escribas código y evitamos trabajo duplicado.

Para errores pequeños o mejoras de documentación puedes ir directo al Pull Request.

## Flujo de trabajo

1. Haz un fork del repositorio.
2. Crea una rama desde `master`:

   ```bash
   git checkout -b feat/nuevo-modo-limpieza
   ```

   Usa prefijos `feat/`, `fix/` o `docs/` y nombres en kebab-case.

3. Haz commits atómicos siguiendo [Conventional Commits](https://www.conventionalcommits.org/es/v1.0.0/):

   ```text
   feat(linux): añade limpieza de caché de paquetes Snap
   fix(windows): evita borrar la papelera si está en uso
   docs(readme): aclara el requisito de jq en Debian
   ```

4. Abre un Pull Request contra `master` explicando qué cambia y cómo lo probaste.

## Entorno de desarrollo

No hay dependencias que instalar. Solo necesitas el sistema donde vas a probar:

- **Windows:** PowerShell 5.1+ y una terminal elevada.
- **Linux:** `bash`, `sudo` y `jq` o `python3`.
- **Opcional:** [ShellCheck](https://www.shellcheck.net/) para revisar el script de Linux.

Comprobaciones mínimas antes de enviar:

```bash
# Sintaxis del script de Linux
bash -n linux/cleaner.sh

# Simulación: no debe borrar nada
sudo ./linux/cleaner.sh --dry-run

# Análisis estático, si tienes ShellCheck
shellcheck linux/cleaner.sh
```

En Windows, ejecuta siempre primero una simulación:

```powershell
.\windows\Cleaner.ps1 -Mode Completo -DryRun
```

## Estándares de código

- **Bash:** `set -uo pipefail`, funciones en snake_case, mensajes en español y salida por `log`.
- **PowerShell:** `Set-StrictMode -Version Latest`, funciones en `Verb-Noun` y parámetros con `ValidateSet` cuando corresponda.
- **Configuración:** las claves nuevas deben tener un valor por defecto sensato y documentarse en el README.
- **Formato:** respeta `.editorconfig` (UTF-8, LF, 4 espacios; 2 en JSON).
- **Tests:** el repositorio no tiene suite automatizada. Toda contribución debe incluir al menos una prueba manual descrita en el PR y pasar `--dry-run` sin errores.

## Checklist del Pull Request

- [ ] El cambio está explicado y justificado.
- [ ] `bash -n linux/cleaner.sh` pasa sin errores (si tocaste Linux).
- [ ] `--dry-run` / `-DryRun` termina sin borrar nada.
- [ ] Las claves nuevas de configuración tienen valor por defecto.
- [ ] Actualicé `README.md` y `CHANGELOG.md` si el comportamiento visible cambió.
- [ ] No incluí logs, rutas personales ni credenciales.
- [ ] El commit sigue Conventional Commits.

## Proceso de revisión

Reviso los Pull Requests cuando puedo, sin plazos fijos. Si el cambio es grande, puede que tarde en sentarme con calma a probarlo en Windows y Linux. Te responderé con dudas o comentarios en el propio PR.

## Acuerdo de contribución

No hay CLA. Al enviar una contribución aceptas que se incorpore al proyecto bajo **Apache License 2.0** (`Apache-2.0`), la misma licencia del repositorio.

## Código de conducta

- Trata a las demás personas con respeto, también cuando no compartas su criterio.
- Crítica el código, no a quien lo escribió.
- No publiques datos personales, rutas privadas ni información de terceros.
- Si alguien reporta un problema de seguridad, no lo expongas en público antes de que haya una corrección.

Con eso basta. No hace falta un documento más largo para recordar que detrás de cada issue hay una persona.

## Licencia

Las contribuciones quedan bajo **Apache License 2.0** (`Apache-2.0`). Consulta [LICENSE](LICENSE) y [NOTICE](NOTICE).
