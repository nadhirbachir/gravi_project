using AutoMapper;
using gravi_application.Interfaces;
using gravi_application.Mappings;
using gravi_application.Mappings.Resolvers;
using gravi_application.Services;
using gravi_domain.Entities;
using gravi_infrastructure.Data.ConnectionFactories;
using gravi_infrastructure.Data.Interfaces;
using gravi_infrastructure.Data.UnitOfWork;
using Microsoft.AspNetCore.Identity;

namespace gravi_presentation.StartupExtensions
{
    public static class ServiceCollectionExtensions
    {
        public static IServiceCollection AddAutoMapperProfiles(this IServiceCollection services)
        {
            services.AddAutoMapper(config =>
            {
                config.AddProfile<CountryProfile>();
                config.AddProfile<PersonProfile>();
                config.AddProfile<UserProfile>();
                // Or scan entire assembly
                // config.AddMaps(Assembly.GetExecutingAssembly());
            });
            return services;
        }

        public static IServiceCollection AddApplicationServices(this IServiceCollection services)
        {
            services.AddScoped<IUnitOfWork, UnitOfWork>();
            services.AddScoped<IUnitOfWorkAsync, UnitOfWork>();
            services.AddScoped<ICountryService, CountryService>();

            services.AddScoped<PasswordHasher<User>>();
            services.AddScoped<PasswordHashResolver>();
            services.AddScoped<CountryResolver>();

            services.AddScoped<IUserPersonFactoryService, UserPersonFactoryService>();
            return services;
        }

        public static IServiceCollection AddInfrastructureServices(this IServiceCollection services)
        {

            // Register IDbConnectionFactory as a Singleton
            // Only one instance will be created for the entire application lifetime.
            // It automatically resolves IConfiguration and ILogger<DbConnection>.
            services.AddSingleton<IDbConnectionFactory, NpgsqlConnectionFactory>();
            return services;
        }
    }
}
