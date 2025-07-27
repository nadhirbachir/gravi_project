using AutoMapper;
using gravi_application.DTOs;
using gravi_domain.Entities;
using Microsoft.AspNetCore.Identity;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace gravi_application.Mappings.Resolvers
{
    public class PasswordHashResolver : IValueResolver<AddUserDTO, User, string>
    {
        private readonly PasswordHasher<User> _passwordHasher;

        public PasswordHashResolver(PasswordHasher<User> passwordHasher)
        {
            _passwordHasher = passwordHasher;
        }

        public string Resolve(AddUserDTO src, User dst, string dstMember, ResolutionContext context)
        {
            string hashedPassword = _passwordHasher.HashPassword(null, src.Password);

            return hashedPassword;
        }
    }
}
