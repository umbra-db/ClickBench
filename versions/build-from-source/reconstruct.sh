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
#   * isnan/isinf/isfinite -> force-included std:: shim for gcc-5 libstdc++
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

# -- glob the two small libraries so renamed sources are still picked up --
cat > libs/libdaemon/CMakeLists.txt <<'EOF'
file(GLOB daemon_src src/*.cpp)
add_library(daemon ${daemon_src})
target_link_libraries(daemon dbms)
EOF

python3 - <<'PY'
import re, os
# libcommon: replace the explicit source list with a glob
f = "libs/libcommon/CMakeLists.txt"; s = open(f).read()
s = re.sub(r"add_library\s*\(\s*common.*?\)",
           "file(GLOB common_src src/*.cpp)\nadd_library(common ${common_src})",
           s, count=1, flags=re.S)
open(f, "w").write(s)

# dbms top-level add_library lists many headers/sources; drop any that this
# snapshot doesn't have, and drop the (unvendored) mongoclient link name.
f = "dbms/CMakeLists.txt"; s = open(f).read()
m = re.search(r"add_library\s*\(\s*dbms(.*?)\)", s, flags=re.S)
if m:
    kept = [t for t in m.group(1).split()
            if not t.endswith((".h", ".cpp", ".inc")) or os.path.exists("dbms/" + t)]
    s = s[:m.start()] + "add_library (dbms\n\t" + "\n\t".join(kept) + ")" + s[m.end():]
s = re.sub(r"\bmongoclient\b", "", s)
open(f, "w").write(s)
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

# -- generate the re2_st (single-threaded re2) headers into a stable include dir --
mkdir -p contrib/re2_st_gen
( cd contrib/re2_st_gen && sh /src/contrib/libre2/create_st_headers.sh /src/contrib/libre2 . )

# -- gcc-5 libstdc++ moved isnan/isinf/isfinite into std::; bridge them back --
mkdir -p contrib/compat
cat > contrib/compat/cmath_compat.h <<'EOF'
#pragma once
#include <cmath>
using std::isnan;
using std::isinf;
using std::isfinite;
EOF

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
    BlockInputStreamPtr loadAll() override { throw Exception("MongoDB not supported", 0); }
    bool supportsSelectiveLoad() const override { return false; }
    BlockInputStreamPtr loadIds(const std::vector<std::uint64_t> &) override { throw Exception("MongoDB not supported", 0); }
    BlockInputStreamPtr loadKeys(const ConstColumnPlainPtrs &, const std::vector<std::size_t> &) override { throw Exception("MongoDB not supported", 0); }
    bool isModified() const override { return false; }
    DictionarySourcePtr clone() const override { throw Exception("MongoDB not supported", 0); }
    std::string toString() const override { return "MongoDB(disabled)"; }
};
}
EOF

# -- root CMakeLists: add the quicklz/re2_st include dirs and, on the C++ flags,
#    -fpermissive plus the force-included cmath shim (anchored on the donor's
#    stable libcityhash include line / -std=gnu++1y flag) --
sed -i 's#include_directories (${METRICA_SOURCE_DIR}/contrib/libcityhash/)#include_directories (${METRICA_SOURCE_DIR}/contrib/quicklz-stub/)\ninclude_directories (${METRICA_SOURCE_DIR}/contrib/re2_st_gen/)\ninclude_directories (${METRICA_SOURCE_DIR}/contrib/libcityhash/)#' CMakeLists.txt
sed -i 's#-std=gnu++1y#-std=gnu++1y -fpermissive -include ${METRICA_SOURCE_DIR}/contrib/compat/cmath_compat.h#' CMakeLists.txt

echo "reconstruct.sh: build system reconciled"
