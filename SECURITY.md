# Seguridad de Cleaner

Cleaner ejecuta operaciones destructivas sobre el sistema de archivos, así que cualquier fallo que pueda borrar datos importantes, saltarse una confirmación o elevar privilegios se trata como un problema de seguridad.

## Versiones soportadas

El repositorio no publica tags ni versiones numeradas. Se mantiene la última revisión de la rama `master`.

| Versión | Soporte |
| --- | --- |
| Última revisión de `master` | Sí |
| Revisiones anteriores | No |

## Cómo reportar una vulnerabilidad

Usa el **reporte privado de GitHub**:

1. Entra en la pestaña **Security** del repositorio.
2. Pulsa **Report a vulnerability**.
3. Rellena el formulario con el detalle que se indica abajo.

Si el reporte privado no está habilitado, contacta conmigo desde mi perfil de GitHub: [github.com/Saaarmyx](https://github.com/Saaarmyx).

**No abras un issue público** para reportar una vulnerabilidad. Tampoco publiques la ruta exacta que se borra ni un script de explotación antes de que exista una corrección.

## Qué incluir en el reporte

- Descripción clara del problema.
- Pasos para reproducirlo, con el sistema operativo y la versión de PowerShell o Bash.
- Impacto esperado: qué archivos o ajustes se ven afectados y con qué permisos.
- Versión o commit afectado.
- Si lo tienes, una propuesta de corrección o el fragmento de código implicado.

## Tiempos

Es un proyecto personal. Respondo en cuanto puedo, sin plazos garantizados. Te confirmaré que recibí el reporte y te mantendré al tanto mientras lo reviso.

## Divulgación responsable

Te pido que no divulgues el detalle hasta que exista una corrección publicada. Si el fallo afecta a datos del usuario, la prioridad será publicar una salvaguarda cuanto antes, aunque la corrección completa llegue después.

## Reconocimiento

Si quieres, te acredito en el CHANGELOG o en la release de la corrección. Dime cómo prefieres aparecer (nombre, usuario de GitHub o enlace) al enviar el reporte.
