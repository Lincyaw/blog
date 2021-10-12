---
title: "一些示例和注意事项"
date: 2021-08-06T21:16:10+08:00
description: "新服务器的第一篇博客当然是写怎么搭环境啦"
draft: false
image: "test.jpg"
math: true  
categories:
    - 测试
tags: 
    - 这是文章的标签
---

个人链接汇总：[https://www.lincyaw.xyz](https://www.lincyaw.xyz)

[官方的content management文档](https://gohugo.io/content-management/)

[本主题支持的 FrontMatter](https://docs.stack.jimmycai.com/zh/writing/supported-front-matter-fields.html)

[本主题的示例网站，里面有很多示例](https://demo.stack.jimmycai.com/)，包括但不限于：
- 中文测试
- 图片测试
- markdown 风格测试
- 富文本（嵌入视频）
- 数学公式支持
- emoji支持

下面的部分不会在首页显示。但是在hugo里好像并没有什么影响。

<!--more-->

## 一些注意事项

1. 一篇文章占据一个文件夹。里面的文件名必须是叫做`index.md`，否则会导致图片无法解析。
![test photo](test.jpg)

2. 想要在子目录挂载博客的话，需要安装 extended 版本的 hugo。

```
snap install hugo --channel=extended
```

## 在服务器部署博客

众所周知，`hugo server`只能在本地启动一个端口提供服务，直接使用`hugo`可以生成一个`public/`文件夹，里面就是一些静态网页的文件。

那么我们要做的就是把这个文件夹拷贝到服务器里就好了；经过在官网文档的一番探索，我决定使用`Rsync`进行部署。

### 第一步

把本地的`ssh`密钥拷贝到服务器里。
```sh
ssh-keygen # 在服务器生成密钥
cp id_rsa.pub authorized_keys # 把本地的公钥写入的服务器的 authorized_keys 中，这样用ssh登录时就不需要输密码了
```


### 第二步

在项目根目录创建一个 shell 脚本，我创建为 `deploy.sh`

内容如下
```sh
#!/bin/sh
USER=root
HOST=服务器的ip地址
DIR=服务器上要存放的目录
hugo && rsync -avz --delete public/ ${USER}@${HOST}:${DIR}
exit 0
```

对这个文件进行 `chmod +x deploy.sh`，以后就可以用`./deploy.sh`命令来上传静态网站文件了。

更新：写了一个 makefile，一键推送，感觉更加方便。

```makefile
	USER=root
	HOST=服务器的ip地址
	DIR=要拷贝的目标地址
ALL:
	make push && make deploy

push:
	git add .
	git commit -m "update"
	git push

deploy:
	git submodule update
	hugo && rsync -avz --delete public/ $(USER)@$(HOST):$(DIR)

```


### 第三步

我使用的 nginx + docker 的形式进行提供 web 服务。因为自己安装的话可能会导致自己不知道改了哪些东西；卸载重装可能又没有卸载干净，比较麻烦。

```docker
docker pull nginx # 拉取最新的 nginx 镜像
```

因为目前这个华为云的服务器还没有域名，我已经备案域名在腾讯云的服务器上，所以暂时还不需要修改nginx的配置文件。只需要将静态网页所在的文件夹挂载到容器里即可。

```docker
docker run --name hugo -p 2021:80 -v /root/site:/usr/share/nginx/html -d nginx

# --name: 重命名 container 为 hugo，方便查找
# -p: 将容器内的 80 端口映射到主机的 2021 端口
# -v: 将主机的 /root/site 文件夹挂载到内部的 /usr/share/nginx/html；由于原先的配置文件里显示的网页就是在这个目录的，所以我们只需要挂载即可
# -d: 设置容器一直在后台运行
```

当服务器可以配置域名后，可以挂载一下相关的配置文件。配置文件见 [gitee 仓库](https://gitee.com/lincyaw/configs)的`configs`。里面放的是 nginx 容器里默认的配置。（服务器上 github 太卡了）

配置目录分别在：
```
/etc/nginx/nginx.conf
/etc/nginx/conf.d/default.conf
```
其实也不难发现，在`nginx.conf`文件夹里的最后一行写着 `include /etc/nginx/conf.d/*.conf;`，表明`nginx.conf`类似于一个总的文件，包含了`conf.d`里的所有带`.conf`后缀的配置。

到时候只需要修改对应的配置文件，然后将其挂载到 docker 里即可。

```
docker run --name hugo \
-p 80:80 \
-v /root/site:/usr/share/nginx/html/blog   \ # 博客
-v /root/nginx-configs:/usr/share/nginx/html   \ # 主页
-v /root/nginx-configs/nginx.conf:/etc/nginx/nginx.conf  \ # 配置文件 
-v /root/nginx-configs/default.conf:/etc/nginx/conf.d/default.conf  \ # 配置文件


docker run --name hugo -p 80:80 -v /root/site:/usr/share/nginx/html/blog -v /root/nginx-configs:/usr/share/nginx/html -v /root/nginx-configs/nginx.conf:/etc/nginx/nginx.conf -v /root/nginx-configs/default.conf:/etc/nginx/conf.d/default.conf -d nginx
```