using gravi_domain.Enums;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace gravi_application.DTOs
{
    public class AddPersonDTO
    {
        //public enum GenderType { NotProvided = 0, Male = 1, Female = 2 };

        [StringLength(50, MinimumLength = 2, ErrorMessage = "Length of first name need to be in the range of 2-50 characters only.")]
        public required string FirstName { get; set; }
        [MaxLength(50, ErrorMessage = "Can't make the middle name over 50 characters.")]
        public string? MiddleName { get; set; }

        [StringLength(50, MinimumLength = 2, ErrorMessage = "Length of last name need to be in the range of 2-50 characters only.")]
        public required string LastName { get; set; }
        public required string CountryName { get; set; }
        public required DateTime DateOfBirth { get; set; }
        public required GenderType Gender { get; set; }
    }
}
