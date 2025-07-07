using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging; // Make sure this is included for ILogger
using gravi_infrastructure.Data.Interfaces;
using gravi_infrastructure.Data.ConnectionFactories;
using System.Data.Common;
using System.Data;
using Microsoft.Extensions.Logging.Console;

namespace gravi_presentation
{
    public class StartUp
    {
        // This method replaces Startup.ConfigureServices
        public static void ConfigureServices(IServiceCollection services, IConfiguration configuration)
        {

            // Add framework services
            services.AddControllers();
            // Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
            services.AddEndpointsApiExplorer();
            services.AddSwaggerGen();

            // Register IDbConnectionFactory as a Singleton
            // Only one instance will be created for the entire application lifetime.
            // It automatically resolves IConfiguration and ILogger<DbConnection>.
            services.AddSingleton<IDbConnectionFactory, NpgsqlConnectionFactory>();
            
        }

        // This method replaces Startup.Configure
        public static void Configure(WebApplication app, IWebHostEnvironment env)
        {
            // Configure the HTTP request pipeline.
            if (app.Environment.IsDevelopment())
            {
                app.UseSwagger();
                app.UseSwaggerUI();
            }

            app.UseHttpsRedirection();
            app.UseRouting();
            app.UseAuthorization();
            app.MapControllers(); // Use MapControllers with WebApplication
        }
    }
}
