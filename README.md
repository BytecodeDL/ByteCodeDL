# ByteCodeDL

A declarative static analysis tool for jvm bytecode based Datalog like CodeQL

## Why ByteCodeDL

ByteCodeDL这个名字是从CodeQL演化的，ByteCode对应Code，DL对应QL，是一款声明式静态分析工具，主要是为了弥补CodeQL无法直接分析字节码的遗憾。

本项目主要有两个目的：

1. 教学目的，帮助大家入门静态分析，本项目将演示如何通过datalog实现一些静态分析算法，比起命令式静态分析，这种方式要简洁很多，学习了基本原理之后，也可以自己DIY规则。
2. 提高挖洞效率，安全研究人员一般拿不到源码，大多数情况只能分析Jar包，然后通过IDEA看反编译之后的代码，效率比较低，希望ByteCodeDL提供的搜索功能、调用图分析功能、污点分析功能，能够提高安全研究人员的挖洞效率。

## Install

1. [download](https://github.com/BytecodeDL/soot-fact-generator/releases/download/v1.0/soot-fact-generator.jar) or [build](https://github.com/BytecodeDL/soot-fact-generator) soot-fact-generator.jar
2. install [souffle](https://souffle-lang.github.io/install) 
3. install [neo4j](https://neo4j.com/download-center/)

## Docker

you can use the docker we builded like docker-compose.yml

## Features

- [x] 搜索功能
- [ ] 调用图分析
  - [x] CHA
  - [ ] RTA
- [ ] 指针分析
  - [x] 上下文无关指针分析
  - [ ] 一阶上下文调用点敏感指针分析
  - [ ] 一阶上下文对象敏感指针分析
  - [ ] 一阶上下文类型敏感指针分析
- [ ] 污点分析
  - [x] 上下文无关ptaint

## Usage

见docs文件夹

## Acknowledgement

- 感谢南大的李樾和谭添两位老师，通过他们开设的[程序分析课程](https://pascal-group.bitbucket.io/teaching.html)入门了静态分析这一领域。
- 感谢[Doop](https://bitbucket.org/yanniss/doop) , 提供了soot-fact-generator.jar 。
