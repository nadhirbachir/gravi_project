using gravi_presentation;

var builder = WebApplication.CreateBuilder(args);


// Add services to the container.
StartUp.ConfigureServices(builder.Services, builder.Configuration);


var app = builder.Build();


StartUp.Configure(app, app.Environment);

app.Run();
