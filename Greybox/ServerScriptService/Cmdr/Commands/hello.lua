return {
	Name = "hello";
	Aliases = {"hi"};
	Description = "A simple hello world command";
	Group = "Admin";
	Args = {
		{
			Type = "fruit";
			Name = "fruit";
			Description = "A fruit to send with your greeting";
		}
	}
}
