# Services

Verified as of 2026-10. Sign-up pages change: if a button or permission name no longer matches, follow the service's own docs linked in its section and tell the user what differs.

Three services, collected in this order. Each section gives the steps to show the user, the env var, what OpenMontage uses the key for, and what is lost if the user skips it. What to do with each `check_key.ps1` result is defined only in SKILL.md § Steps 2–4.

Pexels is not collected: it has paused issuing new API keys, so new users cannot get one. Do not re-add it until https://www.pexels.com/api/ issues keys again.

Contents: [Hugging Face](#hugging-face) · [Pixabay](#pixabay) · [ElevenLabs](#elevenlabs)

## Hugging Face

- **Env var:** `HF_TOKEN`
- **Used for:** speaker diarization in the transcriber (who speaks when) through WhisperX and pyannote.
- **If skipped:** transcription still works; multi-speaker footage gets no speaker labels.
- **Cost:** free.
- **Docs:** https://huggingface.co/docs/hub/security-tokens

Steps for the user:

1. Sign up at https://huggingface.co/join and confirm the email.
2. Open https://huggingface.co/settings/tokens → **Create new token** → token type **Read** → name `openmontage` → **Create token**, then copy it.
3. Open https://huggingface.co/pyannote/speaker-diarization-community-1 and click **Agree and access repository**. Diarization needs this model; the token alone is not enough.

## Pixabay

- **Env var:** `PIXABAY_API_KEY`
- **Used for:** free stock video and images for B-roll and inserts.
- **If skipped:** OpenMontage uses the remaining stock sources.
- **Cost:** free.
- **Docs:** https://pixabay.com/api/docs/

Steps for the user:

1. Sign up at https://pixabay.com/accounts/register/ (Google sign-in works).
2. While signed in, open https://pixabay.com/api/docs/ and scroll to **Parameters**. The value in the `key (required)` row is the key.

## ElevenLabs

- **Env var:** `ELEVENLABS_API_KEY`
- **Used for:** narration (text to speech), generated music and sound effects.
- **If skipped:** narration falls back to the offline Piper voice; no generated music or sound effects.
- **Cost:** free plan with monthly credits and no commercial licence; paid plans add a commercial licence. Current prices: https://elevenlabs.io/pricing
- **Docs:** https://elevenlabs.io/docs/api-reference/authentication

Steps for the user:

1. Sign up at https://elevenlabs.io/app/sign-up.
2. Open https://elevenlabs.io/app/developers/api-keys → **Create API Key** → name `openmontage`.
3. Set permissions: **Text to Speech**, **Speech to Text**, **Sound Effects** and **Music** — Access; **User** — Read. `check_key.ps1` validates the key through the User endpoint, so User Read is required.
4. Create the key and copy it — ElevenLabs shows it only once.

An existing ElevenLabs key can be reused if it has every permission above; otherwise the user edits its permissions or creates a new one.
