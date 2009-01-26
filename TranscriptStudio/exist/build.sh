#!/bin/bash

# will be set by the installer
if [ -z "$EXIST_HOME" ]; then
	EXIST_HOME="C:\Program Files\eXist"
fi

if [ -z "$JAVA_HOME" ]; then
    JAVA_HOME="C:\Program Files\Java\jdk1.6.0_07"
fi

if [ ! -d "$JAVA_HOME" ]; then
    JAVA_HOME="C:\Program Files\Java\jre6"
fi

JAVA_CMD="$JAVA_HOME/bin/java"

ANT_HOME="$EXIST_HOME/tools/ant"

LOCALCLASSPATH=$CLASSPATH:$ANT_HOME/lib/ant-launcher.jar:$ANT_HOME/lib/junit-4.4.jar

JAVA_ENDORSED_DIRS="$EXIST_HOME"/lib/endorsed

JAVA_OPTS="-Dant.home=$ANT_HOME -Djava.endorsed.dirs=$JAVA_ENDORSED_DIRS -Dexist.home=$EXIST_HOME"

echo Starting Ant...
echo

$JAVA_HOME/bin/java -Xms64m -Xmx512m $JAVA_OPTS -classpath $LOCALCLASSPATH org.apache.tools.ant.launch.Launcher $*