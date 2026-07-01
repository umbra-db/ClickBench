#!/bin/bash
# Reconstruct the build system for a pre-2016-03 ClickHouse snapshot.
#
# The public repo only became self-contained (root CMakeLists + contrib/) at
# 2016-03. Earlier snapshots have the *source* but no build system and no
# vendored libraries. This script runs inside a checkout where the target
# source is at /src and a donor commit's build system (root CMakeLists, all
# per-dir CMakeLists, cmake modules and contrib/) has already been overlaid on
# top (see Dockerfile.reconstruct). It then reconciles the donor build files
# with the older source:
#
#   * glob libcommon/libdaemon sources        -> absorbs file renames
#     (Daemon.cpp->BaseDaemon.cpp, Revision.cpp->ClickHouseRevision.cpp, ...)
#   * prune donor-listed files absent here    -> handles added/removed files
#   * disable the tests/ targets              -> they list snapshot-specific files
#   * QuickLZ  -> header-only stub  (dropped at open-sourcing; never imported.
#                 The quicklz codec is never produced/consumed with LZ4/ZSTD data)
#   * re2_st   -> generated from contrib/libre2 via the donor's create_st_headers.sh
#   * MongoDB  -> throwing stub (legacy mongoclient driver never vendored)
#
# Idempotent-ish: intended to run once on a fresh overlay.

set -eu
cd /src

# -- strip -Werror (and the clang-only -Wno-* flags that leak into the gcc build) --
find /src -name CMakeLists.txt -o -name '*.cmake' | xargs -r sed -i 's/-Werror//g'

# -- drop the tests/ subdirectories: they enumerate files that don't all exist
#    in an older snapshot, which is a fatal cmake configure error --
find /src -name CMakeLists.txt | xargs -r sed -i 's/add_subdirectory *( *tests *)//g'
sed -i 's/INCLUDE(add.test.cmake)//' CMakeLists.txt || true

# -- drop add_subdirectory(private): the Yandex-internal Metrica code was never
#    open-sourced (appears in the 2016-06+ trees). --
find /src -name CMakeLists.txt | xargs -r sed -i '/add_subdirectory *( *private *)/d'

# -- drop the utils/ subdirectory: standalone tools we don't need, some of which
#    reference sources absent in older snapshots (a fatal configure error). --
sed -i '/add_subdirectory *( *utils *)/d' CMakeLists.txt || true

# -- Old libstdc++ ABI: this era used the refcounted (COW) std::string (8 bytes),
#    which the code's sizing assumes (e.g. Field's DBMS_TOTAL_FIELD_SIZE=32).
#    Build with _GLIBCXX_USE_CXX11_ABI=0 to get that string back (see the CXX
#    flags injection below), rather than resizing structs for the new 32-byte ABI. --

# -- glob the two small libraries so renamed sources are still picked up --
cat > libs/libdaemon/CMakeLists.txt <<'EOF'
file(GLOB daemon_src src/*.cpp)
add_library(daemon ${daemon_src})
target_link_libraries(daemon dbms)
EOF

python3 - <<'PY'
import re, os, glob
# CMakeLists in this era carry UTF-8 (Russian) comments; the container's Python
# may default to ASCII, so read/write with an explicit codec that round-trips
# arbitrary bytes.
def rd(p): return open(p, encoding="utf-8", errors="surrogateescape").read()
def wr(p, s): open(p, "w", encoding="utf-8", errors="surrogateescape").write(s)

# libcommon: replace the explicit source list with a glob (handles renames like
# Revision.cpp -> ClickHouseRevision.cpp where the target has a file the donor
# build files don't list).
f = "libs/libcommon/CMakeLists.txt"; s = rd(f)
s = re.sub(r"add_library\s*\(\s*common.*?\)",
           "file(GLOB common_src src/*.cpp)\nadd_library(common ${common_src})",
           s, count=1, flags=re.S)
wr(f, s)

# Drop the (never-vendored) mongoclient link name wherever it appears.
f = "dbms/CMakeLists.txt"; wr(f, re.sub(r"\bmongoclient\b", "", rd(f)))

# The dbms library is one huge explicit source list in dbms/CMakeLists.txt.
# Replace it with a recursive glob so sources renamed/moved between the target
# snapshot and the donor are all compiled (Server/Client are separate
# executables, tests are disabled). cmake 3.5 has no list(FILTER), so filter in
# a foreach.
f = "dbms/CMakeLists.txt"; s = rd(f)
glob_block = (
    'file(GLOB_RECURSE dbms_all_sources src/*.cpp)\n'
    'set(dbms_sources "")\n'
    'foreach(f ${dbms_all_sources})\n'
    '  if((NOT f MATCHES "/(Server|ODBC|tests)/") AND (NOT f MATCHES "/Client/(Client|Benchmark).cpp"))\n'
    '    list(APPEND dbms_sources ${f})\n'
    '  endif()\n'
    'endforeach()\n'
    'add_library (dbms ${dbms_sources})'
)
# The dbms lib includes the Client library code (Connection*.cpp) but not the
# client executable mains (Client.cpp/Benchmark.cpp); all of Server/ is the
# server executable; ODBC is a separate driver; tests are disabled.
s = re.sub(r"add_library\s*\(\s*dbms\b.*?\)", glob_block, s, count=1, flags=re.S)
wr(f, s)

# Generic prune: the donor build files (2016-03) list sources that an *older*
# target snapshot doesn't have yet (files added later). For every add_library /
# add_executable in every CMakeLists, drop any listed source file that doesn't
# exist relative to that CMakeLists's directory — otherwise cmake configure
# fails with "Cannot find source file".
SRC_RE = re.compile(r".+\.(cpp|cc|cxx|c|h|hpp|inc)$", re.I)
def prune(cml):
    d = os.path.dirname(cml); s = rd(cml)
    def fix(m):
        head, body = m.group(1), m.group(2)
        kept = [t for t in body.split()
                if not SRC_RE.match(t) or os.path.exists(os.path.join(d, t))]
        return head + " " + " ".join(kept) + ")"
    s2 = re.sub(r"(add_(?:library|executable)\s*\(\s*[^\s)]+)(.*?)\)", fix, s, flags=re.S|re.I)
    if s2 != s: wr(cml, s2)
# os.walk (not glob(recursive=), which needs Python 3.5+; trusty ships 3.4).
for root, _dirs, files in os.walk("."):
    if "CMakeLists.txt" in files:
        prune(os.path.join(root, "CMakeLists.txt"))
PY

# -- QuickLZ compile/link stub (dead code path: our data is LZ4/ZSTD) --
mkdir -p contrib/quicklz-stub/quicklz
cat > contrib/quicklz-stub/quicklz/quicklz_level1.h <<'EOF'
#pragma once
#include <cstddef>
// QuickLZ was removed at the 2016-03 open-sourcing and never imported to the
// public repo. The quicklz compression method is never produced or consumed
// here (data uses LZ4/ZSTD), so these symbols only need to compile and link.
struct qlz_state_compress { char scratch[1000000]; };
struct qlz_state_decompress { char scratch[1000000]; };
inline size_t qlz_compress(const void *, char * dst, size_t size, qlz_state_compress *) { (void)dst; return size; }
inline size_t qlz_size_compressed(const char *) { return 0; }
inline size_t qlz_size_decompressed(const char *) { return 0; }
inline size_t qlz_decompress(const char *, void *, qlz_state_decompress *) { return 0; }
EOF
cp contrib/quicklz-stub/quicklz/quicklz_level1.h contrib/quicklz-stub/quicklz/quicklz_level2.h
cp contrib/quicklz-stub/quicklz/quicklz_level1.h contrib/quicklz-stub/quicklz/quicklz_level3.h

# -- vendor Poco/Ext/ScopedTry.h: a Poco extension (scoped try-lock) the early
#    trees use but that isn't in the donor's Poco. Placed on Poco's include path. --
mkdir -p contrib/libpoco/Foundation/include/Poco/Ext
cat > contrib/libpoco/Foundation/include/Poco/Ext/ScopedTry.h <<'EOF'
#pragma once
// Scoped try-lock (default-construct, then lock(&mutex) attempts tryLock and
// returns success; the mutex is released on scope exit if held). Reconstructed
// to match the early-ClickHouse usage in MergeTreeData::grabOldParts.
namespace Poco
{
template <class M>
class ScopedTry
{
public:
    ScopedTry() : _mutex(0) {}
    ~ScopedTry() { if (_mutex) _mutex->unlock(); }
    bool lock(M * mutex) { if (mutex->tryLock()) { _mutex = mutex; return true; } return false; }
private:
    M * _mutex;
    ScopedTry(const ScopedTry &);
    ScopedTry & operator=(const ScopedTry &);
};
}
EOF

# -- statdaemons compat: the early trees pull several headers from an external
#    Yandex library ("statdaemons") that the donor split up and renamed:
#      * the embedded dictionaries -> DB/Dictionaries/Embedded/ (header-only), and
#      * the daemon base class Daemon -> libs/libdaemon's BaseDaemon.
#    Both were overlaid from the donor by the Dockerfile. Expose them at the old
#    <statdaemons/...> paths (dict headers forward to Embedded; daemon.h forwards
#    to BaseDaemon with a typedef for the old class name; Interests.h — legacy
#    OLAP interest categories, unused by the benchmark — is an empty stub). --
mkdir -p contrib/statdaemons-compat/statdaemons
# Auto-map every donor header of the same basename to the old <statdaemons/X.h>
# path: the statdaemons library's contents were dispersed into DB/Common/,
# common/ and DB/Dictionaries/Embedded/ (e.g. Exception.h -> DB/Common/Exception.h,
# RegionsHierarchies.h -> Embedded/). First match wins (DB/Common preferred).
# (DB/Core is scanned last so the newer DB/Common location wins when both exist:
#  in the oldest trees Exception.h/etc. still lived under DB/Core, not DB/Common.)
for pair in "dbms/include/DB/Common:DB/Common" "libs/libcommon/include/common:common" "dbms/include/DB/Dictionaries/Embedded:DB/Dictionaries/Embedded" "dbms/include/DB/Core:DB/Core"; do
    dir="${pair%%:*}"; inc="${pair##*:}"; [ -d "$dir" ] || continue
    for h in "$dir"/*.h; do
        [ -f "$h" ] || continue; base="$(basename "$h")"
        w="contrib/statdaemons-compat/statdaemons/${base}"
        [ -e "$w" ] || printf '#pragma once\n#include <%s/%s>\n' "$inc" "$base" > "$w"
    done
done
if [ -f libs/libdaemon/include/daemon/BaseDaemon.h ]; then
    printf '#pragma once\n#include <daemon/BaseDaemon.h>\ntypedef BaseDaemon Daemon;\n' \
        > contrib/statdaemons-compat/statdaemons/daemon.h
    # The donor's BaseDaemon is newer and drags in evolved deps (zkutil/graphite)
    # the older tree lacks. Replace it with a thin no-op base carrying just the
    # API the early Server/TCPHandler use (Poco::Util::ServerApplication plus
    # isCancelled/writeToGraphite/getGraphiteWriter, and the Application
    # using-decl the old daemon.h exposed). Metrics/cancellation become no-ops,
    # which is fine for the benchmark.
    cat > libs/libdaemon/include/daemon/GraphiteWriter.h <<'EOF'
#pragma once
#include <string>
#include <vector>
#include <utility>
#include <ctime>
class GraphiteWriter
{
public:
    template <typename T> using KeyValuePair = std::pair<std::string, T>;
    template <typename T> using KeyValueVector = std::vector<KeyValuePair<T>>;
    template <typename T> void write(const std::string &, const T &, time_t = 0, const std::string & = "") {}
    template <typename T> void write(const KeyValueVector<T> &, time_t = 0, const std::string & = "") {}
};
EOF
    cat > libs/libdaemon/include/daemon/BaseDaemon.h <<'EOF'
#pragma once
#include <Poco/Util/ServerApplication.h>
#include <Poco/Util/Option.h>
#include <Poco/Util/OptionSet.h>
#include <daemon/GraphiteWriter.h>
#include <memory>
#include <string>
#include <ctime>
using Poco::Util::Application;
class BaseDaemon : public Poco::Util::ServerApplication
{
public:
    bool isCancelled() { return is_cancelled; }
    static BaseDaemon & instance() { return dynamic_cast<BaseDaemon &>(Poco::Util::Application::instance()); }
    template <typename T> void writeToGraphite(const std::string & key, const T & value, time_t timestamp = 0, const std::string & custom_root_path = "") { if (graphite_writer) graphite_writer->write(key, value, timestamp, custom_root_path); }
    template <typename T> void writeToGraphite(const GraphiteWriter::KeyValueVector<T> & key_vals, time_t timestamp = 0, const std::string & custom_root_path = "") { if (graphite_writer) graphite_writer->write(key_vals, timestamp, custom_root_path); }
    GraphiteWriter * getGraphiteWriter() { return graphite_writer.get(); }
protected:
    // The real daemon registered --config-file and loaded it; replicate that so
    // the server accepts the entrypoint's --config-file and reads its config.
    void defineOptions(Poco::Util::OptionSet & options) override
    {
        Poco::Util::ServerApplication::defineOptions(options);
        options.addOption(Poco::Util::Option("config-file", "C", "config file").required(false)
            .repeatable(false).argument("<file>").binding("config-file"));
    }
    void initialize(Poco::Util::Application & self) override
    {
        if (config().hasProperty("config-file"))
            loadConfiguration(config().getString("config-file"));
        Poco::Util::ServerApplication::initialize(self);
    }
    bool is_cancelled = false;
    std::unique_ptr<GraphiteWriter> graphite_writer;
};
EOF
    rm -f libs/libdaemon/src/*.cpp
    printf '// minimal daemon base (see reconstruct.sh)\n' > libs/libdaemon/src/BaseDaemon.cpp
fi
echo '#pragma once' > contrib/statdaemons-compat/statdaemons/Interests.h

# -- Yandex/ -> common/: the old include prefix for the common utilities that the
#    donor renamed to common/ (e.g. <Yandex/Common.h> == <common/Common.h>).
#    Expose the donor's common headers under the old Yandex/ prefix. --
if [ -d libs/libcommon/include/common ]; then
    mkdir -p contrib/yandex-compat
    ln -sfn "$(pwd)/libs/libcommon/include/common" contrib/yandex-compat/Yandex
fi

# -- double-conversion: the old code includes <src/double-conversion.h>; the
#    donor's header is double-conversion/double-conversion.h (same namespace). --
if [ -f contrib/libdouble-conversion/double-conversion/double-conversion.h ]; then
    mkdir -p contrib/dc-compat/src
    printf '#pragma once\n#include <double-conversion/double-conversion.h>\n' > contrib/dc-compat/src/double-conversion.h
fi

# -- stats/*: the pre-2015-12 trees include several headers from an external Yandex
#    "stats" library that was never open-sourced. At the 2015-11 -> 2015-12 boundary
#    these were inlined into the repo (a coordinated refactor). We reproduce that:
#      * stats/IntHash.h   -> the templated intHash32<salt>+IntHash32 functor, which
#        2015-12 moved into DB/Common/HashTable/Hash.h. Append them to the era's
#        own Hash.h (which lacks intHash32) so they are visible everywhere Hash.h is
#        included -- notably the overlaid UniquesHashSet -- and forward the old
#        <stats/IntHash.h> path there. (Appending, not a separate compat definition,
#        avoids a double-definition when both headers land in one TU.)
#      * stats/{UniquesHashSet,ReservoirSampler,ReservoirSamplerDeterministic}.h ->
#        the algorithms, overlaid in-tree from PATCH_REF and forwarded. --
mkdir -p contrib/stats-compat/stats
HASH_H=dbms/include/DB/Common/HashTable/Hash.h
# (Match the definition `intHash32(` -- not the prose comment that mentions the
#  name -- so we don't skip the append on a false positive.)
if [ -f "$HASH_H" ] && ! grep -q 'intHash32(' "$HASH_H"; then
    cat >> "$HASH_H" <<'EOF'

/// Added by reconstruct.sh: the templated salted UInt64 -> UInt32 hash (ttwang) and
/// its container functor. Before 2015-12 these lived in the external <stats/IntHash.h>;
/// 2015-12 moved them into this header. Kept identical to the 2015-12 definition.
template <DB::UInt64 salt>
inline DB::UInt32 intHash32(DB::UInt64 key)
{
	key ^= salt;
	key = (~key) + (key << 18);
	key = key ^ ((key >> 31) | (key << 33));
	key = key * 21;
	key = key ^ ((key >> 11) | (key << 53));
	key = key + (key << 6);
	key = key ^ ((key >> 22) | (key << 42));
	return key;
}

template <typename T, DB::UInt64 salt = 0>
struct IntHash32
{
	size_t operator() (const T & key) const { return intHash32<salt>(key); }
};
EOF
fi
printf '#pragma once\n#include <DB/Common/HashTable/Hash.h>\n' > contrib/stats-compat/stats/IntHash.h

# The overlaid 2015-12 ReservoirSampler{,Deterministic}.h back a small sample buffer
# with DB::PODArray<T, N, AllocatorWithStackMemory<Allocator<false>, N>> -- but
# 2015-11's Allocator is a non-template class and lacks AllocatorWithStackMemory, and
# back-porting the templated allocator would ripple through every container. The
# buffer only ever needs push_back / [] / size / resize / begin / end / clear / swap,
# so retarget it to std::vector (the first PODArray template arg is the element type).
# quantile() is unused by the benchmark, so exact reservoir behaviour is immaterial.
for f in dbms/include/DB/AggregateFunctions/ReservoirSampler.h \
         dbms/include/DB/AggregateFunctions/ReservoirSamplerDeterministic.h; do
    [ -f "$f" ] || continue
    sed -i 's#include <DB/Common/PODArray.h>#include <vector>#' "$f"
    sed -i 's#using Array = DB::PODArray<\([^,]*\),[^;]*>;#using Array = std::vector<\1>;#' "$f"
done

# Forward the old <stats/...> algorithm paths to the overlaid in-tree headers.
for base in ReservoirSampler ReservoirSamplerDeterministic UniquesHashSet; do
    if [ -f "dbms/include/DB/AggregateFunctions/${base}.h" ]; then
        printf '#pragma once\n#include <DB/AggregateFunctions/%s.h>\n' "$base" \
            > "contrib/stats-compat/stats/${base}.h"
    fi
done

# -- generate the re2_st (single-threaded re2) headers into a stable include dir --
mkdir -p contrib/re2_st_gen
( cd contrib/re2_st_gen && sh /src/contrib/libre2/create_st_headers.sh /src/contrib/libre2 . )


# -- MongoDB dictionary: throwing stub (legacy mongoclient driver not vendored) --
cat > dbms/include/DB/Dictionaries/MongoDBBlockInputStream.h <<'EOF'
#pragma once
// Stub: MongoDB support removed (legacy mongoclient driver not vendored).
EOF
cat > dbms/include/DB/Dictionaries/MongoDBDictionarySource.h <<'EOF'
#pragma once
#include <DB/Dictionaries/IDictionarySource.h>
#include <DB/Common/Exception.h>
#include <Poco/Util/AbstractConfiguration.h>
#include <string>
#include <vector>
namespace DB
{
struct DictionaryStructure;
class Block;
class Context;
// MongoDB dictionary support is disabled in this reconstructed build; requesting
// a mongodb dictionary source throws. Never exercised by the benchmark.
class MongoDBDictionarySource final : public IDictionarySource
{
public:
    MongoDBDictionarySource(const DictionaryStructure &, const Poco::Util::AbstractConfiguration &,
        const std::string &, Block &, Context &)
    { throw Exception("MongoDB dictionary source is not supported in this build", 0); }
    // No `override` on these: the exact IDictionarySource virtuals vary across the
    // era (e.g. loadKeys did not exist before ~2015-12). Omitting the keyword makes
    // each an implicit override where the matching virtual exists and a harmless
    // extra method where it doesn't, so the stub is concrete for every snapshot.
    BlockInputStreamPtr loadAll() { throw Exception("MongoDB not supported", 0); }
    bool supportsSelectiveLoad() const { return false; }
    BlockInputStreamPtr loadIds(const std::vector<std::uint64_t> &) { throw Exception("MongoDB not supported", 0); }
    BlockInputStreamPtr loadKeys(const ConstColumnPlainPtrs &, const std::vector<std::size_t> &) { throw Exception("MongoDB not supported", 0); }
    bool isModified() const { return false; }
    DictionarySourcePtr clone() const { throw Exception("MongoDB not supported", 0); }
    std::string toString() const { return "MongoDB(disabled)"; }
};
}
EOF

# -- member-template virt-specifiers: the early trees mark templated member
#    functions with `override`/`final` (e.g. `template <typename T> bool
#    execute(...) override` in FunctionsMiscellaneous.h). A member template can
#    never be virtual, so this is ill-formed; the era's compiler accepted it but
#    gcc-5 rejects it ("member template ... may not have virt-specifiers"). Strip
#    the trailing specifier from any method whose immediately-preceding non-blank
#    line opens a `template<...>` declaration. --
python3 - <<'PYEOF'
import os, re
# ") ... override|final" at end of a declaration line (body brace on next line)
spec = re.compile(r'\)\s*(?:const\s*)?(?:override|final)(?:\s+(?:override|final))?\s*$')
tmpl = re.compile(r'^\s*template\s*<')
for root, _dirs, files in os.walk('dbms'):
    for fn in files:
        if not fn.endswith(('.h', '.hpp', '.cpp')):
            continue
        p = os.path.join(root, fn)
        try:
            with open(p, encoding='utf-8', errors='surrogateescape') as f:
                lines = f.readlines()
        except OSError:
            continue
        changed = False
        prev_nonblank = ''
        for i, ln in enumerate(lines):
            if spec.search(ln) and tmpl.match(prev_nonblank):
                # drop just the virt-specifier keyword(s), keep the rest verbatim
                lines[i] = re.sub(r'\s*(?:override|final)(?:\s+(?:override|final))?\s*$', '\n', ln)
                changed = True
            if ln.strip():
                prev_nonblank = ln
        if changed:
            with open(p, 'w', encoding='utf-8', errors='surrogateescape') as f:
                f.writelines(lines)
PYEOF

# -- root CMakeLists: add the quicklz/re2_st include dirs and, on the C++ flags,
#    -fpermissive plus the force-included cmath shim (anchored on the donor's
#    stable libcityhash include line / -std=gnu++1y flag) --
sed -i 's#include_directories (${METRICA_SOURCE_DIR}/contrib/libcityhash/)#include_directories (${METRICA_SOURCE_DIR}/contrib/quicklz-stub/)\ninclude_directories (${METRICA_SOURCE_DIR}/contrib/re2_st_gen/)\ninclude_directories (${METRICA_SOURCE_DIR}/contrib/statdaemons-compat/)\ninclude_directories (${METRICA_SOURCE_DIR}/contrib/yandex-compat/)\ninclude_directories (${METRICA_SOURCE_DIR}/contrib/dc-compat/)\ninclude_directories (${METRICA_SOURCE_DIR}/contrib/stats-compat/)\ninclude_directories (${METRICA_SOURCE_DIR}/contrib/libcityhash/)#' CMakeLists.txt
# Force-include a few standard headers: on this (trusty) toolchain they aren't
# pulled in transitively the way the newer 16.04/boost-1.58 headers were, so code
# that assumes std::accumulate (<numeric>) / std::mt19937 (<random>) is in scope
# fails to compile without them.
sed -i 's#-std=gnu++1y#-std=gnu++1y -fpermissive -D_GLIBCXX_USE_CXX11_ABI=0 -include numeric -include random#' CMakeLists.txt

echo "reconstruct.sh: build system reconciled"
