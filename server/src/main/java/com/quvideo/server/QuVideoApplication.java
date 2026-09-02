package com.quvideo.server;

import org.mybatis.spring.annotation.MapperScan;
import org.springframework.boot.WebApplicationType;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.builder.SpringApplicationBuilder;

@SpringBootApplication
@MapperScan("com.quvideo.server.mapper")
public class QuVideoApplication {

	public static void main(String[] args) {
		//使用 Builder 模式，强制指定为 SERVLET Web 应用
		//这能彻底防止它找不到 Web 服务器
		new SpringApplicationBuilder(QuVideoApplication.class)
				.web(WebApplicationType.SERVLET)
				.run(args);
	}
}