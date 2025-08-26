using AutoMapper;
using Google.Protobuf.WellKnownTypes;
using gravi_application.Interfaces;
using gravi_application.Mappings;
using gravi_application.Mappings.Resolvers;
using gravi_application.Services;
using gravi_domain.Entities;
using gravi_infrastructure.Data.ConnectionFactories;
using gravi_infrastructure.Data.Interfaces;
using gravi_infrastructure.Data.UnitOfWork;
using gravi_presentation.AuthConfiguration.Authentications.JwtAuthentications;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using System.Text;

namespace gravi_presentation.StartupExtensions
{
    public static class ServiceCollectionExtensions
    {
        public static IServiceCollection AddAuthenticationServices(this IServiceCollection services, IConfiguration config)
        {
            // getting the jwt options from the comfiguration
            ServiceProvider serviceProvider = services.BuildServiceProvider();
            JwtOptions jwtOptions = serviceProvider.GetRequiredService<IOptions<JwtOptions>>().Value;

            // setting up the jwt authentication token configuratation 
            services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
                .AddJwtBearer(options =>
                {
                    options.SaveToken = true;
                    options.TokenValidationParameters = new TokenValidationParameters
                    {
                        ValidateIssuer = true,
                        ValidIssuer = jwtOptions.Issuer,
                        ValidateAudience = true,
                        ValidAudience = jwtOptions.Audience,
                        ValidateLifetime = true,
                        ValidateIssuerSigningKey = true,
                        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtOptions.SigningKey)),
                        ClockSkew = TimeSpan.FromSeconds(10)
                    };
                });

            return services;
        }

        public static IServiceCollection AddAuthorizationServices(this IServiceCollection services)
        {
            // TODO: add authorization (permissions, policies, roles)
            services.AddAuthorization(); 
            
            return services;
        }

        public static IServiceCollection AddAutoMapperProfiles(this IServiceCollection services)
        {
            services.AddAutoMapper(config =>
            {
                config.AddProfile<CountryProfile>();
                config.AddProfile<PersonProfile>();
                config.AddProfile<UserProfile>();
                // Or scan entire assembly (I had some problems using this so I got them one by one)
                // config.AddMaps(Assembly.GetExecutingAssembly());
            });
            return services;
        }

        public static IServiceCollection AddApplicationServices(this IServiceCollection services)
        {
            services.AddScoped<IUnitOfWork, UnitOfWork>();
            services.AddScoped<IUnitOfWorkAsync, UnitOfWork>();
            services.AddScoped<ICountryService, CountryService>();
            services.AddScoped<IUserService,  UserService>();

            services.AddScoped<PasswordHasher<User>>();
            services.AddScoped<PasswordHashResolver>();
            services.AddScoped<CountryResolver>();

            services.AddScoped<IUserPersonFactoryService, UserPersonFactoryService>();
            return services;
        }

        public static IServiceCollection AddInfrastructureServices(this IServiceCollection services, IConfiguration config)
        {

            // Register IDbConnectionFactory as a Singleton
            // Only one instance will be created for the entire application lifetime.
            // It automatically resolves IConfiguration and ILogger<DbConnection>.
            services.AddSingleton<IDbConnectionFactory, NpgsqlConnectionFactory>();
            services.Configure<JwtOptions>(config.GetSection("Jwt"));
            return services;
        }
    }
}
