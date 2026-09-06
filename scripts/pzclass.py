"""Minimal Java .class reader for resolving Project Zomboid API names.

Parses the constant pool and the field/method tables of a class inside
projectzomboid.jar. Used to answer one question exactly: does this name
actually exist in the installed game?

Why fields and methods rather than a raw constant-pool grep: a constant-pool
grep matches any string that happens to appear anywhere in the class, so it
reports `Perks.Foraging` as valid because the word "Foraging" is in some
unrelated literal. Six of the seven bugs found in Session 16, and the
ChurchStorageMisc bug found in Session 17, were that exact false positive.
"""

import struct
import zipfile

# Constant pool tags that carry a payload we must skip over correctly.
_TAG_UTF8 = 1
_TAG_INT = 3
_TAG_FLOAT = 4
_TAG_LONG = 5
_TAG_DOUBLE = 6
_TAG_CLASS = 7
_TAG_STRING = 8
_TAG_FIELDREF = 9
_TAG_METHODREF = 10
_TAG_IFACEREF = 11
_TAG_NAMEANDTYPE = 12
_TAG_HANDLE = 15
_TAG_METHODTYPE = 16
_TAG_DYNAMIC = 17
_TAG_INVOKEDYNAMIC = 18
_TAG_MODULE = 19
_TAG_PACKAGE = 20

# tag -> number of bytes to skip after the tag byte
_FIXED_WIDTH = {
    _TAG_INT: 4, _TAG_FLOAT: 4, _TAG_LONG: 8, _TAG_DOUBLE: 8,
    _TAG_CLASS: 2, _TAG_STRING: 2, _TAG_FIELDREF: 4, _TAG_METHODREF: 4,
    _TAG_IFACEREF: 4, _TAG_NAMEANDTYPE: 4, _TAG_HANDLE: 3,
    _TAG_METHODTYPE: 2, _TAG_DYNAMIC: 4, _TAG_INVOKEDYNAMIC: 4,
    _TAG_MODULE: 2, _TAG_PACKAGE: 2,
}

ACC_PUBLIC = 0x0001
ACC_STATIC = 0x0008
ACC_FINAL = 0x0010
ACC_ENUM = 0x4000


class ClassFile:
    def __init__(self, pool, fields, methods, super_name=None):
        self.pool = pool          # index -> str for UTF8 entries, else None
        self.fields = fields      # list of (name, descriptor, access_flags)
        self.methods = methods    # list of (name, descriptor, access_flags)
        self.super_name = super_name   # e.g. 'zombie/iso/objects/IsoObject'

    def field_names(self, static_only=False):
        return {n for n, _d, f in self.fields
                if not static_only or (f & ACC_STATIC)}

    def enum_constants(self):
        """Static fields flagged ACC_ENUM: the enum's declared constants."""
        return {n for n, _d, f in self.fields if (f & ACC_ENUM)}

    def constants(self):
        """Names usable as `ClassName.NAME` from Lua.

        Covers both shapes PZ uses: a true Java enum (ACC_ENUM constants,
        e.g. Capability) and a plain holder class of public static final
        fields (e.g. PerkFactory$Perks, which is NOT an enum despite Lua
        code treating `Perks.X` like one).
        """
        want = ACC_PUBLIC | ACC_STATIC | ACC_FINAL
        return {n for n, _d, f in self.fields
                if (f & ACC_ENUM) or (f & want) == want}

    def method_names(self):
        return {n for n, _d, _f in self.methods}

    def method_arities(self):
        """name -> set of argument counts, self excluded.

        Java overloads share a name, so a call is valid if ANY overload takes
        that many arguments. Descriptors are parsed rather than counted by
        comma: `(Ljava/lang/String;IZ)V` is three arguments, not one.
        """
        out = {}
        for name, desc, _f in self.methods:
            out.setdefault(name, set()).add(_descriptor_arity(desc))
        return out


def _descriptor_arity(desc):
    """Number of parameters in a JVM method descriptor."""
    args = desc[desc.index("(") + 1:desc.rindex(")")]
    n, i = 0, 0
    while i < len(args):
        while args[i] == "[":
            i += 1
        if args[i] == "L":
            i = args.index(";", i) + 1
        else:
            i += 1
        n += 1
    return n


def _read_pool(data, off):
    count = struct.unpack_from(">H", data, off)[0]
    off += 2
    pool = [None] * count
    class_refs = {}          # pool index of a CONSTANT_Class -> its name index
    i = 1
    while i < count:
        tag = data[off]
        if tag == _TAG_CLASS:
            class_refs[i] = struct.unpack_from(">H", data, off + 1)[0]
        off += 1
        if tag == _TAG_UTF8:
            length = struct.unpack_from(">H", data, off)[0]
            off += 2
            pool[i] = data[off:off + length].decode("utf-8", "replace")
            off += length
        else:
            width = _FIXED_WIDTH.get(tag)
            if width is None:
                raise ValueError("unknown constant pool tag %d at %d" % (tag, off - 1))
            off += width
        # long and double occupy two pool slots (JVMS 4.4.5)
        i += 2 if tag in (_TAG_LONG, _TAG_DOUBLE) else 1
    return pool, class_refs, off


def _read_members(data, off, pool):
    count = struct.unpack_from(">H", data, off)[0]
    off += 2
    out = []
    for _ in range(count):
        access, name_i, desc_i, attr_count = struct.unpack_from(">HHHH", data, off)
        off += 8
        for _a in range(attr_count):
            attr_len = struct.unpack_from(">I", data, off + 2)[0]
            off += 6 + attr_len
        out.append((pool[name_i], pool[desc_i], access))
    return out, off


def parse(data):
    if data[:4] != b"\xca\xfe\xba\xbe":
        raise ValueError("not a class file")
    off = 8                                   # magic + minor + major
    pool, class_refs, off = _read_pool(data, off)
    _access, _this, super_i = struct.unpack_from(">HHH", data, off)
    off += 6
    # super_class is 0 only for java/lang/Object itself.
    super_name = pool[class_refs[super_i]] if super_i in class_refs else None
    iface_count = struct.unpack_from(">H", data, off)[0]
    off += 2 + iface_count * 2
    fields, off = _read_members(data, off, pool)
    methods, off = _read_members(data, off, pool)
    return ClassFile(pool, fields, methods, super_name)


class Jar:
    """Lazy accessor for classes inside projectzomboid.jar."""

    def __init__(self, jar_path):
        self._zip = zipfile.ZipFile(jar_path)
        self._cache = {}

    def klass(self, path):
        """path e.g. 'zombie/characters/Capability'"""
        if path not in self._cache:
            self._cache[path] = parse(self._zip.read(path + ".class"))
        return self._cache[path]

    def has_class(self, path):
        try:
            self._zip.getinfo(path + ".class")
            return True
        except KeyError:
            return False

    def class_paths(self):
        return [n[:-6] for n in self._zip.namelist() if n.endswith(".class")]

    def chain(self, path):
        """The class and every superclass of it that is inside the jar.

        Method lookup has to walk this. IsoThumpable declares setIsThumpable
        but inherits getModData, setAlphaAndTarget and getSquare from IsoObject,
        so asking IsoThumpable alone would report real methods as missing --
        a checker that cries wolf stops being read.
        """
        out = []
        seen = set()
        while path and path not in seen and self.has_class(path):
            seen.add(path)
            out.append(self.klass(path))
            path = out[-1].super_name
        return out

    def methods_deep(self, path):
        """name -> set of valid argument counts, across the whole chain."""
        merged = {}
        for k in self.chain(path):
            for name, arities in k.method_arities().items():
                merged.setdefault(name, set()).update(arities)
        return merged
