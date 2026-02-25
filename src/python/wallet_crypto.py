import os
import base64
import secrets
from typing import Optional

from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.backends import default_backend

SALT_LEN = 16
NONCE_LEN = 12
PBKDF2_ITERATIONS = 100000
KEY_LEN = 32


def _get_master_key() -> bytes:
    key_hex = os.getenv('WALLET_ENCRYPTION_KEY')
    if not key_hex or len(key_hex) < 32:
        raise RuntimeError('WALLET_ENCRYPTION_KEY must be set (32+ char hex or 44+ char base64)')
    key_hex = key_hex.strip()
    if len(key_hex) == 64 and all(c in '0123456789abcdefABCDEF' for c in key_hex):
        return bytes.fromhex(key_hex)
    try:
        return base64.urlsafe_b64decode(key_hex + '=='[: (4 - len(key_hex) % 4) % 4])
    except Exception:
        pass
    return bytes.fromhex(key_hex) if len(key_hex) >= 64 else key_hex.encode()[:KEY_LEN].ljust(KEY_LEN, b'\0')


def _derive_key(master: bytes, salt: bytes) -> bytes:
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=KEY_LEN,
        salt=salt,
        iterations=PBKDF2_ITERATIONS,
        backend=default_backend()
    )
    return kdf.derive(master)


def encrypt_private_key(plaintext_hex: str) -> str:
    master = _get_master_key()
    salt = secrets.token_bytes(SALT_LEN)
    nonce = secrets.token_bytes(NONCE_LEN)
    key = _derive_key(master, salt)
    plaintext = bytes.fromhex(plaintext_hex) if all(c in '0123456789abcdefABCDEF' for c in plaintext_hex) else plaintext_hex.encode()
    aes = AESGCM(key)
    ciphertext = aes.encrypt(nonce, plaintext, None)
    return base64.b64encode(salt + nonce + ciphertext).decode('ascii')


def decrypt_private_key(encrypted_b64: str) -> str:
    master = _get_master_key()
    raw = base64.b64decode(encrypted_b64)
    if len(raw) < SALT_LEN + NONCE_LEN + 16:
        raise ValueError('Invalid encrypted blob length')
    salt = raw[:SALT_LEN]
    nonce = raw[SALT_LEN:SALT_LEN + NONCE_LEN]
    ciphertext = raw[SALT_LEN + NONCE_LEN:]
    key = _derive_key(master, salt)
    aes = AESGCM(key)
    plaintext = aes.decrypt(nonce, ciphertext, None)
    return plaintext.hex()


def is_encrypted(value: Optional[str]) -> bool:
    if not value:
        return False
    if len(value) == 64 and all(c in '0123456789abcdefABCDEF' for c in value.lower()):
        return False
    try:
        raw = base64.b64decode(value, validate=True)
        return len(raw) >= SALT_LEN + NONCE_LEN + 16
    except Exception:
        return False


def get_plain_private_key(wallet_row: dict) -> Optional[str]:
    pk = wallet_row.get('flow_private_key')
    if not pk:
        return None
    if is_encrypted(pk):
        return decrypt_private_key(pk)
    return pk
