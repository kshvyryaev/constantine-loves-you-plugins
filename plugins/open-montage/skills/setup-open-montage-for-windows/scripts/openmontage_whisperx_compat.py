"""Let OpenMontage's diarization call work with WhisperX 3.8+ without editing OpenMontage.

OpenMontage calls `whisperx.DiarizationPipeline(use_auth_token=...)`. WhisperX 3.8+ exposes the
class only as `whisperx.diarize.DiarizationPipeline` and names the argument `token`; the call sits
in a broad try/except, so the mismatch silently disables diarization. Loaded at interpreter start
through a .pth file, this module adds `whisperx.DiarizationPipeline` back and maps the argument.
It does nothing when WhisperX is missing or already exposes the class.
"""

import inspect


def _install() -> None:
    try:
        import whisperx
    except Exception:
        return
    if hasattr(whisperx, "DiarizationPipeline"):
        return

    def DiarizationPipeline(*args, use_auth_token=None, **kwargs):
        from whisperx.diarize import DiarizationPipeline as Pipeline

        if use_auth_token is not None:
            params = inspect.signature(Pipeline.__init__).parameters
            name = "use_auth_token" if "use_auth_token" in params else "token"
            kwargs.setdefault(name, use_auth_token)
        return Pipeline(*args, **kwargs)

    whisperx.DiarizationPipeline = DiarizationPipeline


_install()
