using JSUtils;
void main(string[] argv) {
	var ctx = new Context();
	ctx.init_core();
	ctx.exec("""%s""".printf(argv[1]));
}
