"""Build tiny deterministic MaxMind DB v2 fixtures; no downloads required."""
from pathlib import Path
import struct
import sys

MARKER = b'\xab\xcd\xefMaxMind.com'


def size_type(kind, length):
    prefix = b'' if kind <= 7 else bytes([kind - 7])
    code = kind if kind <= 7 else 0
    if length < 29:
        return bytes([(code << 5) | length]) + prefix
    if length < 285:
        return bytes([(code << 5) | 29]) + prefix + bytes([length - 29])
    if length < 65821:
        return bytes([(code << 5) | 30]) + prefix + (length - 285).to_bytes(2, 'big')
    raise ValueError(length)


def encode(value):
    if isinstance(value, str):
        raw = value.encode()
        return size_type(2, len(raw)) + raw
    if isinstance(value, float):
        return size_type(3, 8) + struct.pack('>d', value)
    if isinstance(value, int):
        raw = value.to_bytes(max(1, (value.bit_length() + 7) // 8), 'big')
        return size_type(6, len(raw)) + raw
    if isinstance(value, list):
        return size_type(11, len(value)) + b''.join(encode(e) for e in value)
    if isinstance(value, dict):
        return size_type(7, len(value)) + b''.join(encode(k) + encode(v) for k, v in value.items())
    raise TypeError(type(value))


def node(record_size, left, right):
    if record_size == 24:
        return left.to_bytes(3, 'big') + right.to_bytes(3, 'big')
    if record_size == 28:
        return (left & 0xffffff).to_bytes(3,'big') + bytes([((left >> 24) << 4) | (right >> 24)]) + (right & 0xffffff).to_bytes(3,'big')
    if record_size == 32:
        return left.to_bytes(4,'big') + right.to_bytes(4,'big')
    raise ValueError(record_size)


def make(path, record_size=24, ip_version=4, pointers=False, asn=False, country=False, invalid_location=False, registered=False):
    # One-node tree, left half: no data, right half: City record.
    data = encode({'country': {'names': {'en': 'Testland'}},
                   'city': {'names': {'en': 'Testville'}},
                   'location': {'latitude': 47.12345, 'longitude': 28.98765}})
    if country:
        data = encode({'country': {'names': {'en': 'Testland'}},
                       'continent': {'names': {'en': 'Testcontinent'}}})
    if invalid_location:
        data = encode({'country': {'names': {'en': 'Testland'}},
                       'location': {'latitude': 91.0, 'longitude': 181.0}})
    if registered:
        data = encode({'registered_country': {'names': {'en': 'Registrationland'}}})
    if asn:
        data = encode({'autonomous_system_number': 13335,
                       'autonomous_system_organization': 'Test ISP'})
    if pointers:
        # The first map field references a string following the record.
        prefix = size_type(7, 2) + encode("first") + b"\x20\x00" + encode("other") + encode("inline")
        address = len(prefix)
        data = prefix.replace(b"\x20\x00", bytes([0x20 | (address >> 8), address & 0xff]), 1) + encode("referenced")
    count = 97 if ip_version == 6 else 1
    metadata = encode({
        'node_count': count,
        'record_size': record_size,
        'ip_version': ip_version,
        'database_type': 'GeoLite2-ASN' if asn else ('GeoLite2-Country' if country else 'GeoLite2-City'),
        'binary_format_major_version': 2,
        'binary_format_minor_version': 0,
        'build_epoch': 1780000000,
        'languages': ['en'],
    })
    if ip_version == 6:
        # Follow 96 leading zero bits, then the IPv4 address bits.
        # Separately, ::/0 with its highest bit set points to a record.
        nodes = [node(record_size, 1, count + 16)]
        nodes.extend(node(record_size, i + 1, count) for i in range(1, 96))
        nodes.append(node(record_size, count, count + 16))
        tree = b"".join(nodes)
    else:
        tree = node(record_size, count, count + 16)
    blob = tree + bytes(16) + data + MARKER + metadata
    Path(path).write_bytes(blob)


if __name__ == '__main__':
    for size in (24, 28, 32):
        make(Path(sys.argv[1]) / f'city-{size}.mmdb', size)
    make(Path(sys.argv[1]) / 'city-v6.mmdb', 24, 6)
    make(Path(sys.argv[1]) / 'pointer.mmdb', 24, pointers=True)
    make(Path(sys.argv[1]) / 'asn.mmdb', 24, asn=True)
    make(Path(sys.argv[1]) / 'country.mmdb', 24, country=True)
    make(Path(sys.argv[1]) / 'invalid-location.mmdb', 24, invalid_location=True)
    make(Path(sys.argv[1]) / 'registered.mmdb', 24, registered=True)
    (Path(sys.argv[1]) / 'invalid.mmdb').write_bytes(b'not a maxmind database')
