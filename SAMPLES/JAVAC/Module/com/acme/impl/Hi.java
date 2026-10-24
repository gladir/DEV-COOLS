package com.acme.impl;
public class Hi implements com.acme.api.Greeter { public String greet(String n) { return "Hi " + n; }
  public static void main(String[] a) { for (com.acme.api.Greeter g : java.util.ServiceLoader.load(com.acme.api.Greeter.class)) System.out.println(g.greet("x")); } }
