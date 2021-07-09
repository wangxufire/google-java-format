#!/usr/bin/env bash

die() {
  echo "${@}" 1>&2
  exit 1
}

version=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout)
jar="core/target/google-java-format-${version}-all-deps.jar"

if [ -z "${GRAALVM_HOME}" ]; then
  export GRAALVM_HOME=/Users/wangxufire/workspace/graalvm-ce-java16-21.3.0-dev/Contents/Home
fi

if [[ ! -f "${jar}" ]]; then
  echo "building ${jar}..."
  mvn clean verify -Dmaven.test.skip=true -Dmaven.javadoc.skip=true -Dmaven.source.skip=true -pl core -am || die "cannot build ${jar}"
fi

find ./core/src/main/java -type f -name \*.java >> all-java.txt
mkdir -p core/src/main/resources/META-INF/native-image

"${GRAALVM_HOME}"/bin/java \
  --add-exports=jdk.compiler/com.sun.tools.javac.file=ALL-UNNAMED \
  --add-exports=jdk.compiler/com.sun.tools.javac.main=ALL-UNNAMED \
  --add-exports=jdk.compiler/com.sun.tools.javac.processing=ALL-UNNAMED \
  --add-exports=jdk.compiler/com.sun.tools.javac.parser=ALL-UNNAMED \
  --add-exports=jdk.compiler/com.sun.tools.javac.tree=ALL-UNNAMED \
  --add-exports=jdk.compiler/com.sun.tools.javac.util=ALL-UNNAMED \
  --add-exports=jdk.compiler/com.sun.tools.javac.code=ALL-UNNAMED \
  --add-exports=jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED \
  --add-opens=jdk.compiler/com.sun.tools.javac.comp=ALL-UNNAMED \
  --add-opens=jdk.compiler/com.sun.tools.javac.code=ALL-UNNAMED \
  -agentlib:native-image-agent=config-output-dir=core/src/main/resources/META-INF/native-image \
  -jar "${jar}" --dry-run @all-java.txt

# -H:IncludeResourceBundles=com.sun.tools.javac.resources.javac \
#-H:ConfigurationResourceRoots=META-INF/native-image \
# --initialize-at-build-time \
# --no-server
# -H:-CheckToolchain \
# --no-server
echo "building native image from ${jar}..."

"${GRAALVM_HOME}"/bin/native-image \
  -J--add-exports=jdk.compiler/com.sun.tools.javac.file=ALL-UNNAMED \
  -J--add-exports=jdk.compiler/com.sun.tools.javac.main=ALL-UNNAMED \
  -J--add-exports=jdk.compiler/com.sun.tools.javac.processing=ALL-UNNAMED \
  -J--add-exports=jdk.compiler/com.sun.tools.javac.parser=ALL-UNNAMED \
  -J--add-exports=jdk.compiler/com.sun.tools.javac.tree=ALL-UNNAMED \
  -J--add-exports=jdk.compiler/com.sun.tools.javac.util=ALL-UNNAMED \
  -J--add-exports=jdk.compiler/com.sun.tools.javac.code=ALL-UNNAMED \
  -J--add-exports=jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED \
  -J--add-opens=jdk.compiler/com.sun.tools.javac.comp=ALL-UNNAMED \
  -J--add-opens=jdk.compiler/com.sun.tools.javac.code=ALL-UNNAMED \
  -H:+ReportExceptionStackTraces \
  -H:+ReportUnsupportedElementsAtRuntime \
  -H:ConfigurationFileDirectories=./core/src/main/resources/META-INF/native-image \
  -H:IncludeLocales=zh-CN,en_US \
  -H:IncludeResourceBundles=com.sun.tools.javac.resources.compiler \
  -H:Class=com.google.googlejavaformat.java.Main \
  -H:Name="google-java-format-graal" \
  -Djava.home="${GRAALVM_HOME}" \
  --allow-incomplete-classpath \
  -cp "${jar}" \
  --no-fallback

rm -f all-java.txt
rm -rf core/src/main/resources/META-INF/native-image/

echo "done"
