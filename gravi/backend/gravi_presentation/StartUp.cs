using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using gravi_presentation.StartupExtensions;

namespace gravi_presentation
{
    public class Startup
    {
        public static void ConfigureServices(IServiceCollection services, IConfiguration configuration)
        {
            // Add framework services
            services.AddControllers();
            services.AddEndpointsApiExplorer();
            services.AddSwaggerGen();
            
            // Add custom services
            services.AddAutoMapperProfiles();
            services.AddApplicationServices();
            services.AddInfrastructureServices();
        }

        public static void Configure(WebApplication app, IWebHostEnvironment env)
        {
            if (app.Environment.IsDevelopment())
            {
                app.UseSwagger();
                app.UseSwaggerUI();
            }

            app.UseHttpsRedirection();
            app.UseRouting();
            app.UseAuthorization();
            app.MapControllers();
        }
    }
}