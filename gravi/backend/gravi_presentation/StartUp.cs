using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using gravi_presentation.StartupExtensions;

namespace gravi_presentation
{
    public static class Startup
    {
        public static IServiceCollection ConfigureServices(this IServiceCollection services, IConfiguration config)
        {
            // Add framework services
            services.AddControllers(options => options.AddFilters());
            services.AddEndpointsApiExplorer();
            services.AddSwaggerGen();
            
            // Add custom services
            services.AddAutoMapperProfiles();
            services.AddInfrastructureServices(config);
            services.AddApplicationServices();

            // Setting the Auth services
            services.AddAuthenticationServices(config);
            services.AddAuthorizationServices();

            return services;
        }


        public static WebApplication ConfigureApplication(this WebApplication app)
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

            return app;
        }
    }
}